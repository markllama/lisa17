#! env python3

import sys
import argparse
import jinja2
import yaml

if __name__ == "__main__":

    data = yaml.load(sys.stdin)

    t = jinja2.Template(open(sys.argv[1]).read())

    data['hostname'] = sys.argv[2]


    print(t.render(data))
