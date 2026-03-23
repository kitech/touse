module misskey

$if macos {
    // in vcpkg dir
    #flag -lcurlnm // support ws_send/recv
    #flag -I /opt/vcpkg/root/installed/x64-osx-dynamic/include
}$else{
    $if x32 {
        #flag -lcurl -lssl -lcrypto /opt/vcpkg/installed/x86-linux/lib/libz.a
    } $else {
        #flag -lcurl
    }
}
