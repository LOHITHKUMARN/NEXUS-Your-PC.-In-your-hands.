import ctypes
from ctypes import HRESULT, POINTER, c_wchar_p, c_int, Structure
from comtypes import IUnknown, GUID, COMMETHOD, CoCreateInstance, CLSCTX_ALL
import logging

logger = logging.getLogger("pc_control.policy_config")

# ERole enum from Windows Core Audio APIs
# eConsole = 0, eMultimedia = 1, eCommunications = 2
ERole_eConsole = 0
ERole_eMultimedia = 1
ERole_eCommunications = 2

# Windows 10/11 IPolicyConfig interface ID and class ID
# CLSID_PolicyConfig: {870AF99C-171D-4F9E-AF0D-E63DF40C2BC9}
CLSID_PolicyConfig = GUID('{870AF99C-171D-4F9E-AF0D-E63DF40C2BC9}')

# IPolicyConfig interface definition
class IPolicyConfig(IUnknown):
    _iid_ = GUID('{F8679F50-850A-41CF-9C72-430F290290C8}')
    _methods_ = [
        COMMETHOD([], HRESULT, 'GetMixFormat',
                  (['in'], c_wchar_p, 'pDeviceName'),
                  (['out'], POINTER(c_int), 'ppFormat')),
        COMMETHOD([], HRESULT, 'GetDeviceFormat',
                  (['in'], c_wchar_p, 'pDeviceName'),
                  (['in'], c_int, 'bDefault'),
                  (['out'], POINTER(c_int), 'ppFormat')),
        COMMETHOD([], HRESULT, 'ResetDeviceFormat',
                  (['in'], c_wchar_p, 'pDeviceName')),
        COMMETHOD([], HRESULT, 'SetDeviceFormat',
                  (['in'], c_wchar_p, 'pDeviceName'),
                  (['in'], POINTER(c_int), 'pEndpointFormat'),
                  (['in'], POINTER(c_int), 'pMixFormat')),
        COMMETHOD([], HRESULT, 'GetProcessingPeriod',
                  (['in'], c_wchar_p, 'pDeviceName'),
                  (['in'], c_int, 'bDefault'),
                  (['out'], POINTER(c_int), 'pmftDefaultPeriod'),
                  (['out'], POINTER(c_int), 'pmftMinimumPeriod')),
        COMMETHOD([], HRESULT, 'SetProcessingPeriod',
                  (['in'], c_wchar_p, 'pDeviceName'),
                  (['in'], POINTER(c_int), 'pmftPeriod')),
        COMMETHOD([], HRESULT, 'GetShareMode',
                  (['in'], c_wchar_p, 'pDeviceName'),
                  (['out'], POINTER(c_int), 'pShareMode')),
        COMMETHOD([], HRESULT, 'SetShareMode',
                  (['in'], c_wchar_p, 'pDeviceName'),
                  (['in'], POINTER(c_int), 'pShareMode')),
        COMMETHOD([], HRESULT, 'GetPropertyValue',
                  (['in'], c_wchar_p, 'pDeviceName'),
                  (['in'], c_int, 'bFxStore'),
                  (['in'], POINTER(c_int), 'pKey'),
                  (['out'], POINTER(c_int), 'pv')),
        COMMETHOD([], HRESULT, 'SetPropertyValue',
                  (['in'], c_wchar_p, 'pDeviceName'),
                  (['in'], c_int, 'bFxStore'),
                  (['in'], POINTER(c_int), 'pKey'),
                  (['in'], POINTER(c_int), 'pv')),
        COMMETHOD([], HRESULT, 'SetDefaultEndpoint',
                  (['in'], c_wchar_p, 'wszDeviceId'),
                  (['in'], c_int, 'eRole')),
        COMMETHOD([], HRESULT, 'SetEndpointVisibility',
                  (['in'], c_wchar_p, 'wszDeviceId'),
                  (['in'], c_int, 'bVisible')),
    ]

def set_default_audio_device(device_id: str) -> bool:
    """
    Set default Windows audio playback device by device ID (endpoint ID string).
    Sets both eConsole and eMultimedia roles.
    """
    try:
        policy_config = CoCreateInstance(CLSID_PolicyConfig, IPolicyConfig, CLSCTX_ALL)
        hr1 = policy_config.SetDefaultEndpoint(device_id, ERole_eConsole)
        hr2 = policy_config.SetDefaultEndpoint(device_id, ERole_eMultimedia)
        return hr1 == 0 and hr2 == 0
    except Exception as e:
        logger.warning(f"IPolicyConfig COM switch failed for device {device_id}: {e}")
        # Fallback to powershell AudioDeviceCmdlets or endpoint utility if needed
        return False
