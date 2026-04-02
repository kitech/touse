module fswatch

pub type Handle = voidptr
pub type CEventCallback = fn(Event, voidptr)

pub struct Event {
    pub:
    orig string
    name string
    mask Flag
    flags []Flag
    // ctime time.Time
}
