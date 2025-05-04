# ByteBuddies

To run the code, import gridmaker:
```from gridmaker import generate_puzzle, get_hint```

To generate a puzzle, call this code:
```puzzle, solution = generate_puzzle(difficulty=40)```
The difficulty ranges from 17-81, where 17 is the easiest.

A sukodu 9x9 grid with a valid solution is returned in this format:
```python
[
    [x, x, x, x, x, x, x, x, x],
    [x, x, x, x, x, x, x, x, x],
    ...
    [x, x, x, x, x, x, x, x, x]
]
```
Each x is a number 0-9, where 0s represent blank spaces.


To get a hint, call this code:
```hint = get_hint(puzzle, solution)```

A tuple of the form ```(row, col, number)``` is returned, where:
    row, col are from 0-8,
    the number is the number that is in that place in the solution