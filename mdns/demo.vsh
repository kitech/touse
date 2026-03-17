import os
import time

import mdns

fn normexit() {
    time.sleep(15*time.second)
    exit(0)
}

spawn normexit()
mdns.listen()
