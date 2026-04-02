module fswatch

pub enum Flag {
    noop = 0
    platform_specific //  = C.PlatformSpecific
    created // = C.Created
    updated // = C.Updated
    removed // = C.Removed
    renamed // = C.Renamed
    owner_modified // = C.OwnerModified
    attribute_modified // = C.AttributeModified
    moved_from // = C.MovedFrom
    moved_to // = C.MovedTo
    is_file // = C.IsFile
    is_dir // = C.IsDir
    is_symlink // = C.IsSymLink
    link // = C.Link
    overflow // = C.Overflow
    close_write // = C.CloseWrite
}

pub fn init_library() {}

pub fn new() Handle {
    return nil
}

pub fn (h Handle) add_callback(cbfn CEventCallback, data voidptr) int {
    return 0
}

pub fn (h Handle) add_path(path string) int {
    return 0
}

pub fn (h Handle) start_monitor() int {
    return 0
}
