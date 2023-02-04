'''Library'''
from subprocess import run
from os         import chdir, path

class TestBench():
    '''Attributes'''
    shell:     str
    sim:       str
    testbench: str
    src:       str

    def set_test_env(self):
        '''Setting the parameters of the test environment'''
        chdir(path.dirname(__file__))
        shell = "PowerShell"
        sim   = "iverilog"
        return shell, sim

    def testbench_definition(self, module):
        '''Load testbench'''
        testbench = f'test_{module}'
        srcs = []
        srcs.append(f'{testbench}.v')
        srcs.append(f'../rtl/{module}.v')
        src = ' '.join(srcs)
        return testbench, src

    def add_directive(self):
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

    def remove_directive(self, f0_data, f1_data, f2_data, f3_data):
        '''Remove directive for preprocessor'''
        with open('../rtl/mkio.v', 'wb') as f0:
            f0.write(f0_data)
        with open('../rtl/mkio_control.v', 'wb') as f1:
            f1.write(f1_data)
        with open('../rtl/device3.v', 'wb') as f2:
            f2.write(f2_data)
        with open('../rtl/device5.v', 'wb') as f3:
            f3.write(f3_data)

    def run_sim(self, shell, sim, testbench, src):
        '''Run simulation'''
        build_cmd = [f"{shell}", f"{sim} -o ../sim/{testbench}.vvp {src}"]
        command = ''.join(build_cmd[1])
        print("\033[35m{}\033[31m".format(f'Start command: {command}\n'))
        run(build_cmd, check=True)
        print("\n\033[32m{}\033[0m\n".format('Success!'))

    def run_testbench(self, shell, testbench):
        '''Run testbench'''
        build_cmd = [f"{shell}", f"vvp -N ../sim/{testbench}.vvp"]
        command = ''.join(build_cmd[1])
        print("\033[35m{}\033[0m".format(f'Start command: {command}'))
        run(build_cmd, check=True)

    def run_wave(self, shell,testbench):
        '''Run GTK Wave'''
        gtkwave_attr = '-o -c=4'
        build_cmd = [f"{shell}", f"gtkwave {gtkwave_attr} ../sim/{testbench}.vcd"]
        run(build_cmd, check=True)

def test(module):
    '''main loop'''
    TB = TestBench()
    TB.shell, TB.sim = TB.set_test_env()
    TB.testbench, TB.src = TB.testbench_definition(module)
    f0, f1, f2, f3 = TB.add_directive()
    TB.run_sim(TB.shell, TB.sim, TB.testbench, TB.src)
    TB.remove_directive(f0, f1, f2, f3)
    TB.run_testbench(TB.shell, TB.testbench)
    TB.run_wave(TB.shell, TB.testbench)
test(module='mkio')
