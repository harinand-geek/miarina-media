//! Is there a network at all? Downloads wait for it to come back instead
//! of spending their retries while it is gone (PAR-04). This is only a
//! lookup in the system routing table: no packet is sent.

/// `Some(false)` when the system has no route out (cable unplugged, Wi-Fi
/// off, airplane mode), `Some(true)` when it has one (which does not prove
/// the source answers), `None` when the platform cannot tell.
pub fn has_route() -> Option<bool> {
    #[cfg(windows)]
    {
        Some(windows::route_v4() || windows::route_v6())
    }
    #[cfg(not(windows))]
    {
        None
    }
}

#[cfg(windows)]
mod windows {
    use windows_sys::Win32::NetworkManagement::IpHelper::GetBestInterfaceEx;
    use windows_sys::Win32::Networking::WinSock::{
        AF_INET, AF_INET6, SOCKADDR, SOCKADDR_IN, SOCKADDR_IN6,
    };

    // Documentation addresses (RFC 5737, RFC 3849): only a default route
    // reaches them, and nothing is ever sent there.
    const V4: [u8; 4] = [198, 51, 100, 1];
    const V6: [u8; 16] = [0x20, 0x01, 0x0d, 0xb8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1];

    pub fn route_v4() -> bool {
        let mut addr = SOCKADDR_IN {
            sin_family: AF_INET,
            ..Default::default()
        };
        addr.sin_addr.S_un.S_addr = u32::from_ne_bytes(V4);
        let mut index = 0u32;
        // SAFETY: `addr` is a valid SOCKADDR_IN for the duration of the call.
        unsafe { GetBestInterfaceEx((&raw const addr).cast::<SOCKADDR>(), &mut index) == 0 }
    }

    pub fn route_v6() -> bool {
        let mut addr = SOCKADDR_IN6 {
            sin6_family: AF_INET6,
            ..Default::default()
        };
        addr.sin6_addr.u.Byte = V6;
        let mut index = 0u32;
        // SAFETY: `addr` is a valid SOCKADDR_IN6 for the duration of the call.
        unsafe { GetBestInterfaceEx((&raw const addr).cast::<SOCKADDR>(), &mut index) == 0 }
    }
}

#[cfg(test)]
mod tests {
    #[cfg(windows)]
    #[test]
    fn the_route_lookup_answers_on_windows() {
        // The machine running the tests may be offline; the call must
        // simply answer without failing.
        assert!(super::has_route().is_some());
    }
}
