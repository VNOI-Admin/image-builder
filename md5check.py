icpc = {}
with open('./live-build/icpc/md5sum.txt') as f:
    for line in f:
        checksum, filename = line.split()
        icpc[filename] = checksum

custom = {}
with open('./live-build/image/md5sum.txt') as f:
    for line in f:
        checksum, filename = line.split()
        custom[filename] = checksum

for filename in icpc:
    if filename in custom:
        if icpc[filename] != custom[filename]:
            print(filename, 'is different')
    else:
        print(filename, 'is missing')
