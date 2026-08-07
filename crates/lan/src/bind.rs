use std::net::{IpAddr, Ipv4Addr};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum LanBindMode {
    Loopback,
    AllInterfaces,
}

impl LanBindMode {
    pub fn from_u8(v: u8) -> Self {
        match v {
            1 => Self::AllInterfaces,
            _ => Self::Loopback,
        }
    }

    pub fn bind_addr(self) -> IpAddr {
        match self {
            Self::Loopback => IpAddr::V4(Ipv4Addr::LOCALHOST),
            Self::AllInterfaces => IpAddr::V4(Ipv4Addr::UNSPECIFIED),
        }
    }
}
