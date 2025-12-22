module xml

import vcp

fn test_roxml_build() {
    n := roxml_file('cjk.xml')
    defer {n.close()}
    dump(n.str())
    dump(n.chld_nb())

    n.chld(0).add(.elm, 'hehehhe', '')    
    wtn := n.chld(0).add_elem('wttt')
    n.commit_buffer()
    wtn.del()
    n.commit_buffer()
    dump(n.chld(0).attr('version'))
    dump(n.chld(0).type())
}
