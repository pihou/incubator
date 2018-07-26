#-*- coding=utf8 -*-
from config import *

#pip install qingcloud-sdk
import qingcloud.iaas 
import time
import os

class AutoLogin(object):
    def __init__(self, qy_access_key_id, qy_secret_access_key):
        self.conn = qingcloud.iaas.connect_to_zone("ap1", qy_access_key_id,
                                                   qy_secret_access_key)
        self.instance = ""
        self.eip = ""
        self.public_ip = ""
        self.release_cb = []

    def prepare_login(self):
        #allocate host
        conn = self.conn
        rtn = conn.run_instances(**create_host)
        if rtn.get("ret_code"):
            return False, rtn
        self.instance = rtn["instances"][0]
        cb_info = {
            "func": conn.terminate_instances,
            "kwargs": {
                "instances": [self.instance],
                "zone": "ap1"
            }
        }
        self.release_cb.append(cb_info)

        #allocate public ip
        rtn = conn.allocate_eips(**create_eip)
        if rtn.get("ret_code"):
            return False, rtn
        self.eip = rtn["eips"][0]
        cb_info = {
            "func": conn.release_eips,
            "kwargs": {
                "eips": [self.eip],
                "zone": "ap1"
            }
        }
        self.release_cb.append(cb_info)

        #get public ip info
        rtn = conn.describe_eips(eips=[self.eip], zone="ap1")
        if rtn.get("ret_code"):
            return False, rtn
        self.public_ip = rtn["eip_set"][0]["eip_addr"]
        return True, ""

    def query_prepare_ok(self):
        conn = self.conn
        while True:
            time.sleep(2)
            print "Query Prepare"
            rtn = conn.describe_instances(instances=[self.instance], zone="ap1")
            if rtn.get("ret_code"):
                return False, rtn
            if rtn["instance_set"][0]["status"] == "running":
                break
        rtn = conn.associate_eip(eip=self.eip, instance=self.instance, zone="ap1")
        if rtn.get("ret_code"):
            return False, rtn
        return True, ""

    def login(self):
        login_cmd = "'ssh root@shoupihou.site'"
        os.system('scp ~/.ssh/id_rsa root@%s:~/.ssh/' %(self.public_ip))
        os.system('''ssh root@%s "echo %s >> .bashrc" ''' % (self.public_ip, login_cmd))
        os.system("ssh root@%s" % self.public_ip)

    def query_release_ok(self):
        conn = self.conn
        rtn = conn.dissociate_eips(eips=[self.eip], zone="ap1")
        if rtn.get("ret_code"):
            return False, rtn
        while True:
            time.sleep(2)
            print "Query Release"
            rtn = conn.describe_eips(eips=[self.eip], zone="ap1")
            if rtn.get("ret_code"):
                return False, rtn
            if rtn["eip_set"][0]["status"] == "available":
                break
        return True, ""

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc_value, exc_tb):
        for info in self.release_cb:
            rtn = info["func"](*info.get("args", []), **info.get("kwargs",{}))
            if rtn.get("ret_code"):
                print "Error:", rtn
                return
        return


def main():
    with AutoLogin(qy_access_key_id, qy_secret_access_key) as login:
        ok, msg = login.prepare_login()
        if not ok:
            print "Error", msg
            return
        ok, msg = login.query_prepare_ok()
        if not ok:
            print "Error", msg
            return
        login.login()

        ok, msg = login.query_release_ok()
        if not ok:
            print "Error", msg

if __name__ == "__main__":
    main()

