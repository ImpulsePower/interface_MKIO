import os

module = 'i2c_init'
testbench = 'test_%s' % module

srcs = []

# srcs.append("../rtl/%s.v" % module)
srcs.append("rtl/%s.v" % module)
srcs.append("tb/%s.v" % testbench)

src = ' '.join(srcs)

build_cmd = "iverilog -o %s.vvp %s" % (testbench, src)

if os.system(build_cmd):
    raise Exception("Error running build command")