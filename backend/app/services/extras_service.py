import webbrowser
import subprocess
import logging
import ctypes

logger = logging.getLogger("pc_control.extras")

class ExtrasService:
    def set_clipboard(self, text: str) -> bool:
        try:
            # Use Windows PowerShell Set-Clipboard or ctypes for fast copy
            subprocess.run(
                ["powershell", "-NoProfile", "-Command", f"Set-Clipboard -Value @'\n{text}\n'@"],
                check=True,
                creationflags=subprocess.CREATE_NO_WINDOW
            )
            return True
        except Exception as e:
            logger.error(f"Error setting clipboard: {e}")
            return False

    def open_url(self, url: str) -> bool:
        try:
            url = url.strip()
            if not url:
                return False

            # If user entered a search query or domain without protocol
            if "://" not in url:
                if "." not in url and "localhost" not in url:
                    import urllib.parse
                    url = f"https://www.google.com/search?q={urllib.parse.quote_plus(url)}"
                else:
                    url = "https://" + url

            logger.info(f"Opening URL on PC: {url}")

            # Strategy 1: Native Win32 ShellExecuteW with SW_SHOWNORMAL (1)
            # This is the gold standard on Windows to launch the default browser
            # in the active interactive user desktop session and bring it to the foreground.
            try:
                ret = ctypes.windll.shell32.ShellExecuteW(0, "open", url, None, None, 1)
                if ret > 32:
                    logger.info(f"ShellExecuteW successfully opened {url} (code {ret})")
                    return True
                logger.warning(f"ShellExecuteW returned code {ret}, trying fallback")
            except Exception as e:
                logger.warning(f"ShellExecuteW failed: {e}")

            # Strategy 2: Windows Shell 'start' command via cmd.exe
            try:
                subprocess.Popen(
                    f'cmd.exe /c start "" "{url}"',
                    shell=True
                )
                logger.info(f"cmd.exe start triggered for {url}")
                return True
            except Exception as e:
                logger.warning(f"cmd.exe start fallback failed: {e}")

            # Strategy 3: PowerShell Start-Process
            try:
                subprocess.Popen(
                    ["powershell", "-NoProfile", "-Command", f"Start-Process '{url}'"],
                    creationflags=subprocess.CREATE_NO_WINDOW
                )
                logger.info(f"PowerShell Start-Process triggered for {url}")
                return True
            except Exception as e:
                logger.warning(f"PowerShell Start-Process fallback failed: {e}")

            # Strategy 4: Python standard library webbrowser
            return webbrowser.open(url)
        except Exception as e:
            logger.error(f"Error opening URL {url}: {e}")
            return False

    def show_toast(self, title: str, message: str) -> bool:
        try:
            ps_script = f"""
            [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
            [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] | Out-Null
            $template = @"
            <toast>
                <visual>
                    <binding template="ToastGeneric">
                        <text>{title}</text>
                        <text>{message}</text>
                    </binding>
                </visual>
            </toast>
"@
            $xml = New-Object Windows.Data.Xml.Dom.XmlDocument
            $xml.LoadXml($template)
            $toast = [Windows.UI.Notifications.ToastNotification]::new($xml)
            [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier("PC Control Center").Show($toast)
            """
            subprocess.Popen(
                ["powershell", "-NoProfile", "-Command", ps_script],
                creationflags=subprocess.CREATE_NO_WINDOW
            )
            return True
        except Exception as e:
            logger.error(f"Error showing toast notification: {e}")
            return False

extras_service = ExtrasService()
