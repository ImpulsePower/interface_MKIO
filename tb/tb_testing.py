'''Library'''
from subprocess import call

# # srcs.append("../rtl/%s.v" % module)

# run(["powershell", "ls"])
def set_test_env():
    '''Setting the parameters of the test environment'''
    shell = "PowerShell"
    sim   = "iverilog"
    return shell, sim

def testbench_definition():
    '''Load testbench'''
    module = 'mkio'
    testbench = f'test_{module}'
    srcs = []
    srcs.append(f'rtl/{module}.v')
    srcs.append(f'tb/{testbench}.v')
    src = ' '.join(srcs)
    return testbench, src

def add_directive():
    '''Added directive for preprocessor'''
    return 0

def run_testbench(shell, sim, testbench, src):
    '''Run testbench'''
    # build_cmd = "iverilog -o %s.vvp %s" % (testbench, src)
    call([f"{shell}", f"{sim} -o {testbench}.vvp {src}"])
    # return 0

def main():
    '''main loop'''
    shell, sim = set_test_env()
    testbench, src = testbench_definition()
    add_directive()
    run_testbench(shell, sim, testbench, src)
main()
