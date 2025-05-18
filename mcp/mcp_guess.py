from mcp.server.fastmcp import FastMCP


mcp = FastMCP("Sudoku Server")


@mcp.tool()
def guess_number(number):
  number = int(number)
  if number < 15:
    return 'too small'
  elif number > 15:
    return 'too large'
  return 'You got the number'


if __name__ == "__main__":
    mcp.run()
