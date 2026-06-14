module playwav

#flag -lopenal
#include <AL/al.h>
#include <AL/alc.h>

fn C.playSoundNopcm(filePath &char)
fn C.playSoundPcm(filePath &char)
fn C.alGetError() int

pub const al_no_error = 0

pub fn nopcm(file_path string) ! {
	C.playSoundNopcm(file_path.str)
	err := C.alGetError()
	if err != al_no_error {
		return error('OpenAL error: 0x${err.hex()}')
	}
}

pub fn pcm(file_path string) ! {
	C.playSoundPcm(file_path.str)
	err := C.alGetError()
	if err != al_no_error {
		return error('OpenAL error: 0x${err.hex()}')
	}
}

pub fn last_al_error() int {
	return C.alGetError()
}
