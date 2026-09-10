import asyncio
import ctypes
import logging
from typing import Optional, Tuple
from app.models.schemas import MediaStatus

logger = logging.getLogger("pc_control.media")

# Windows Virtual Key Codes for Hardware Media Control
VK_MEDIA_NEXT_TRACK = 0xB0
VK_MEDIA_PREV_TRACK = 0xB1
VK_MEDIA_STOP = 0xB2
VK_MEDIA_PLAY_PAUSE = 0xB3
KEYEVENTF_KEYUP = 0x0002

def _send_media_key(vk: int) -> bool:
    """Dispatches a standard Windows multimedia keyboard event."""
    try:
        ctypes.windll.user32.keybd_event(vk, 0, 0, 0)
        ctypes.windll.user32.keybd_event(vk, 0, KEYEVENTF_KEYUP, 0)
        logger.info(f"Dispatched hardware media key vk={hex(vk)}")
        return True
    except Exception as e:
        logger.error(f"Failed to dispatch hardware media key {hex(vk)}: {e}")
        return False

class MediaService:
    def __init__(self):
        self._cached_thumbnail_bytes: Optional[bytes] = None
        self._cached_track_key: str = ""
        self._last_status: MediaStatus = MediaStatus()

    async def _get_current_session(self):
        try:
            from winsdk.windows.media.control import GlobalSystemMediaTransportControlsSessionManager as MediaManager
            manager = await asyncio.wait_for(MediaManager.request_async(), timeout=0.25)
            return manager.get_current_session()
        except Exception:
            return None

    def _get_active_audio_app(self) -> Optional[Tuple[str, bool]]:
        """Inspect Core Audio sessions via pycaw to detect any actively streaming application."""
        try:
            from pycaw.pycaw import AudioUtilities
            sessions = AudioUtilities.GetAllSessions()
            for s in sessions:
                if s.State == 1 and s.Process:  # 1 = AudioSessionStateActive
                    pname = s.Process.name()
                    if pname.lower() not in ("system", "idle", "audiodg.exe", "antigravity ide.exe"):
                        return pname, True
        except Exception as e:
            logger.debug(f"CoreAudio inspection error: {e}")
        return None

    async def get_media_status(self) -> MediaStatus:
        try:
            session = await self._get_current_session()
            if session:
                source_app = session.source_app_user_model_id or ""
                playback_info = session.get_playback_info()
                timeline = session.get_timeline_properties()
                
                is_playing = False
                can_play_pause = True
                can_next = True
                can_prev = True
                can_seek = False

                if playback_info:
                    from winsdk.windows.media.control import GlobalSystemMediaTransportControlsSessionPlaybackStatus as PlaybackStatus
                    status = playback_info.playback_status
                    is_playing = (status == PlaybackStatus.PLAYING)
                    
                    controls = playback_info.controls
                    if controls:
                        can_play_pause = controls.is_play_pause_toggle_enabled or controls.is_play_enabled or controls.is_pause_enabled
                        can_next = controls.is_next_enabled
                        can_prev = controls.is_previous_enabled
                        can_seek = controls.is_playback_position_enabled

                pos_ms = 0
                dur_ms = 0
                if timeline:
                    if timeline.position:
                        pos_ms = int(timeline.position.total_seconds() * 1000)
                    if timeline.end_time:
                        dur_ms = int(timeline.end_time.total_seconds() * 1000)

                media_props = await session.try_get_media_properties_async()
                title = media_props.title if media_props else ""
                artist = media_props.artist if media_props else ""
                album = media_props.album_title if media_props else ""
                
                track_key = f"{title}_{artist}_{album}"
                has_thumb = False

                if media_props and media_props.thumbnail:
                    has_thumb = True
                    if track_key != self._cached_track_key:
                        self._cached_track_key = track_key
                        asyncio.create_task(self._extract_thumbnail_bytes(media_props.thumbnail))
                else:
                    if track_key != self._cached_track_key:
                        self._cached_track_key = track_key
                        self._cached_thumbnail_bytes = None

                self._last_status = MediaStatus(
                    has_media=bool(title or is_playing),
                    is_playing=is_playing,
                    title=title,
                    artist=artist,
                    album=album,
                    source_app=source_app,
                    position_ms=pos_ms,
                    duration_ms=dur_ms,
                    has_thumbnail=bool(self._cached_thumbnail_bytes is not None or has_thumb),
                    can_play_pause=can_play_pause,
                    can_next=can_next,
                    can_previous=can_prev,
                    can_seek=can_seek
                )
                return self._last_status

            # Fallback when SMTC has no active track: check Core Audio session
            active_audio = self._get_active_audio_app()
            if active_audio:
                app_name, is_playing = active_audio
                clean_name = app_name.replace('.exe', '').capitalize()
                self._last_status = MediaStatus(
                    has_media=True,
                    is_playing=is_playing,
                    title=f"{clean_name} Audio",
                    artist="Active Audio Stream",
                    album="",
                    source_app=clean_name,
                    can_play_pause=True,
                    can_next=True,
                    can_previous=True,
                )
                return self._last_status

            self._last_status = MediaStatus(
                has_media=False,
                can_play_pause=True,
                can_next=True,
                can_previous=True,
            )
            return self._last_status
        except Exception as e:
            logger.debug(f"Error fetching media status: {e}")
            return self._last_status

    async def _extract_thumbnail_bytes(self, stream_ref):
        try:
            from winsdk.windows.storage.streams import DataReader, InputStreamOptions
            read_stream = await stream_ref.open_read_async()
            size = read_stream.size
            if size > 0:
                reader = DataReader(read_stream)
                reader.input_stream_options = InputStreamOptions.NONE
                await reader.load_async(size)
                
                buf = bytearray(size)
                reader.read_bytes(buf)
                self._cached_thumbnail_bytes = bytes(buf)
        except Exception as e:
            logger.debug(f"Failed to extract thumbnail buffer: {e}")

    def get_cached_thumbnail(self) -> Optional[bytes]:
        return self._cached_thumbnail_bytes

    async def execute_control(self, action: str, position_ms: Optional[int] = None) -> bool:
        """Execute media control, trying SMTC first and falling back to OS hardware media keys."""
        action_lower = action.lower()
        try:
            session = await self._get_current_session()
            if session:
                if action_lower == "play":
                    res = await session.try_play_async()
                    if res:
                        return True
                elif action_lower == "pause":
                    res = await session.try_pause_async()
                    if res:
                        return True
                elif action_lower == "toggle":
                    res = await session.try_toggle_play_pause_async()
                    if res:
                        return True
                elif action_lower == "next":
                    res = await session.try_skip_next_async()
                    if res:
                        return True
                elif action_lower in ("previous", "prev"):
                    res = await session.try_skip_previous_async()
                    if res:
                        return True
                elif action_lower == "seek" and position_ms is not None:
                    target_ticks = int(position_ms * 10000)
                    return await session.try_change_playback_position_async(target_ticks)
        except Exception as e:
            logger.debug(f"SMTC control attempt failed, falling back to hardware keys: {e}")

        # Robust universal fallback: Windows hardware media keys
        if action_lower in ("play", "pause", "toggle"):
            return _send_media_key(VK_MEDIA_PLAY_PAUSE)
        elif action_lower == "next":
            return _send_media_key(VK_MEDIA_NEXT_TRACK)
        elif action_lower in ("previous", "prev"):
            return _send_media_key(VK_MEDIA_PREV_TRACK)
        elif action_lower == "stop":
            return _send_media_key(VK_MEDIA_STOP)
        return False

media_service = MediaService()
