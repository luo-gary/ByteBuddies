#mcp test
from fastmcp import FastMCP

mcp = FastMCP("jls_students")

students = {
    'aryan singhal': 'Is a good student',
    'yunhan luo': 'Wears shoes',
    'martin': 'Has ears',
    'billy' : 'Is not a good student'
}

@mcp.tool
def find_student(name):
    try:
        return f'Information about the requested student: {students[name]}'
    except KeyError:
        return 'Student not found! This student does not exist.'
    
if __name__ == '__main__':
    mcp.run()