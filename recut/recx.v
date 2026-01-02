module recut

import io
import os

// high level api

@[params]
pub struct InsertOption {
    pub mut:
}
@[params]
pub struct QueryOption {
    pub mut:
}
@[params]
pub struct SearchOption {
    pub mut:
}

pub fn Record.ofmap[T](o map[string]T) Record {

    return nil
}
pub fn (rec Record) tomap() map[string]string  {
    res := map[string]string{}
    
    return res 
}

// use struct field attrs
pub fn Record.ofstruct[T](o T) Record {
    
    return nil
}
pub fn Record.tostruct[T](o T) T {
    
    return T{}
}

pub fn (rec Record) dump() ! string {
    buf := charptr(0)
    size := usize(0)
    wrs := Writer.new_str(&buf, &size)
    
    wrs.write_record(rec) !
    wrs.destroy()
    // assert size >= 0

    return buf.tosfree(int(size))    
}


pub fn (db DB) dump() ! string {
    buf := charptr(0)
    size := usize(0)
    wrs := Writer.new_str(&buf, &size)
    
    wrs.write_db(db) !
    wrs.destroy()
    // assert size >= 0

    return buf.tosfree(int(size))    
}

pub fn (db DB) save(filename string) ! {
    

}

pub fn DB.from[T](src T) ! DB {
    match src {
        io.Reader {
            return DB.from_reader(src)
        }
        else{}
    }
    return DB(0)
}


pub fn DB.from_file(filename string) ! DB {
    fp := os.open(filename) !
    fp2 := C.fdopen(fp.fd, c'r');
    defer { fp.close() }
    
    prs := Parser.new(fp2, filename)
    db := prs.db() !
    return db
}
pub fn DB.from_string(s string) ! DB {
    prs := Parser.new_str(s, @FILE_LINE)
    db := prs.db() !
    return db
}
pub fn DB.from_reader(r io.Reader) ! DB {
    return DB(0)
}
