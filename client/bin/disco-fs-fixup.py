import os
import sys

def file_is_text(fname):
    os.system("file %s > /tmp/%s.typeof" % (os.path.abspath("/var/disco/testfs/scratchfs/" + fname), os.getpid()))
    with open("/tmp/%s.typeof" % os.getpid(), "r") as ifile:
        line = ifile.readline()
        if "ASCII" in line:
            return True
    return False

def main(argc, argv):
    for line in sys.stdin.readlines():
        line = line.strip("\n")
        pid = os.getpid()
        if "(CONTENT)" in line:
            fname = line.split(" ")[3]
            if file_is_text(fname):
                content = ""
                
                with open(os.path.abspath("/var/disco/testfs/scratchfs/%s" % fname), "r") as ifile:
                    content = "> " + "> ".join(ifile.readlines())
                line = line.replace("(CONTENT)", "\n%s" % (content))
            elif os.path.isdir("/var/disco/testfs/scratchfs/" + fname):
                line = line.replace("(CONTENT)", "directory")
            else:
                os.system("md5sum /var/disco/testfs/scratchfs/%s > /tmp/%s" % (fname, pid))
                content = ""
                with open("/tmp/%s" % (pid), "r") as ifile:
                    content = ifile.readline().split(" ")[0]
                line = line.replace("(CONTENT)", content)
            line = line.strip("\n")
        if "(OLDMD5SUM)" in line:
            fname = line.split(" ")[3]
            os.system("md5sum /var/disco/testfs/rootfs/%s > /tmp/%s" % (fname, pid))
            content = ""
            with open("/tmp/%s" % (pid), "r") as ifile:
                content = ifile.readline().split(" ")[0]
            line = line.replace("(OLDMD5SUM)", content).strip("\n")
        if "(NEWMD5SUM)" in line:
            fname = line.split(" ")[3]
            os.system("md5sum /var/disco/testfs/scratchfs/%s > /tmp/%s" % (fname, pid))
            content = ""
            with open("/tmp/%s" % (pid), "r") as ifile:
                content = ifile.readline().split(" ")[0]
            line = line.replace("(NEWMD5SUM)", content).strip("\n")
        print line

if __name__ == "__main__":
    sys.exit(main(len(sys.argv), sys.argv))
