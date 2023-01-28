'''Library'''
from subprocess import call
from os import chdir,path

def set_test_env():
    '''Setting the parameters of the test environment'''
    chdir(path.dirname(__file__))
    shell = "PowerShell"
    sim   = "iverilog"
    return shell, sim

def testbench_definition():
    '''Load testbench'''
    module = 'mkio'
    testbench = f'test_{module}'
    srcs = []
    srcs.append(f'{testbench}.v')
    srcs.append(f'../rtl/{module}.v')
    src = ' '.join(srcs)
    return testbench, src

def add_directive():
    '''Added directive for preprocessor'''
    with open('../rtl/mkio.v', 'rb') as f0:
        f0_data = f0.read()
    with open('../rtl/mkio_control.v', 'rb') as f1:
        f1_data = f1.read()
    with open('../rtl/device3.v', 'rb') as f2:
        f2_data = f2.read()
    with open('../rtl/device5.v', 'rb') as f3:
        f3_data = f3.read()
    with open('../rtl/mkio.v', 'a') as f0:
        f0.writelines([
        """\n`include "../rtl/mkio_control.v" """,
        """\n`include "../rtl/mkio_receiver.v" """,
        """\n`include "../rtl/mkio_transmitter.v"\n """
        ])
    with open('../rtl/mkio_control.v', 'a') as f1:
        f1.writelines([
        """\n`include "../rtl/device3.v" """,
        """\n`include "../rtl/device5.v"\n """
        ])
    with open('../rtl/device3.v', 'a') as f2:
        f2.write("""\n`include "../rtl/mem_dev3.v"\n """)
    with open('../rtl/device5.v', 'a') as f3:
        f3.write("""\n`include "../rtl/mem_dev5.v"\n """)

    return f0_data,f1_data,f2_data,f3_data

def run_sim(shell, sim, testbench, src):
    '''Run testbench'''
    build_cmd = [f"{shell}", f"{sim} -o {testbench}.vvp {src}"]
    command = ''.join(build_cmd[1])
    print(f'Start command: {command}\n')
    call(build_cmd)

def remove_directive(f0_data,f1_data,f2_data,f3_data):
    '''Remove directive for preprocessor'''
    with open('../rtl/mkio.v', 'wb') as f0:
        f0.write(f0_data)
    with open('../rtl/mkio_control.v', 'wb') as f1:
        f1.write(f1_data)
    with open('../rtl/device3.v', 'wb') as f2:
        f2.write(f2_data)
    with open('../rtl/device5.v', 'wb') as f3:
        f3.write(f3_data)

def main():
    '''main loop'''
    shell, sim = set_test_env()
    testbench, src = testbench_definition()
    f0,f1,f2,f3 = add_directive()
    run_sim(shell, sim, testbench, src)
    remove_directive(f0,f1,f2,f3)
main()
