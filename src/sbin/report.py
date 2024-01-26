#!/usr/bin/env python3

import psutil
import requests

cpu = psutil.cpu_percent(interval=1)
mem = psutil.virtual_memory().percent
disk = psutil.disk_usage('/').percent

requests.post("http://10.1.0.1:8001/user/report", json={
    "cpu": cpu,
    "mem": mem,
    "disk": disk
})
