import random
import copy
from flask import Flask, jsonify, request
from flask_cors import CORS

app = Flask(__name__)
CORS(app)

def is_valid(grid, row, col, num): #checks if the number is valid in the position
    for x in range(9):
        if grid[row][x] == num:
            return False
    for x in range(9):
        if grid[x][col] == num:
            return False
    start_row, start_col = 3 * (row // 3), 3 * (col // 3)
    for i in range(3):
        for j in range(3):
            if grid[i + start_row][j + start_col] == num:
                return False
    
    return True

def solve_sudoku(grid):
    empty = find_empty(grid)
    if not empty:
        return True
    
    row, col = empty
    for num in range(1, 10):
        if is_valid(grid, row, col, num):
            grid[row][col] = num
            if solve_sudoku(grid):
                return True
            grid[row][col] = 0
    
    return False

def find_empty(grid):
    for i in range(9):
        for j in range(9):
            if grid[i][j] == 0:
                return (i, j)
    return None

def swap_block_rows(grid, row1, row2): #swaps two rows of 3x3 blocks
    for i in range(3):
        grid[row1*3 + i], grid[row2*3 + i] = grid[row2*3 + i], grid[row1*3 + i]

def swap_block_columns(grid, col1, col2): #swaps two columns of 3x3 blocks
    for i in range(9):
        for j in range(3):
            grid[i][col1*3 + j], grid[i][col2*3 + j] = grid[i][col2*3 + j], grid[i][col1*3 + j]

def swap_rows_in_block(grid, block_row, row1, row2): #swaps two rows within the same block row
    grid[block_row*3 + row1], grid[block_row*3 + row2] = grid[block_row*3 + row2], grid[block_row*3 + row1]

def swap_columns_in_block(grid, block_col, col1, col2): #swaps two columns within the same block column
    for i in range(9):
        grid[i][block_col*3 + col1], grid[i][block_col*3 + col2] = grid[i][block_col*3 + col2], grid[i][block_col*3 + col1]

def permute_numbers(grid): #permutes the numbers 1-9 consistently across the whole grid
    numbers = list(range(1, 10))
    random.shuffle(numbers)
    mapping = {i+1: numbers[i] for i in range(9)}
    
    for i in range(9):
        for j in range(9):
            if grid[i][j] != 0:
                grid[i][j] = mapping[grid[i][j]]

def apply_random_transformations(grid): #applies random transformations to the grid
    #swap block rows
    if random.random() < 0.5:
        row1, row2 = random.sample(range(3), 2)
        swap_block_rows(grid, row1, row2)
    
    #swap block columns
    if random.random() < 0.5:
        col1, col2 = random.sample(range(3), 2)
        swap_block_columns(grid, col1, col2)
    
    #swap rows within blocks
    for block_row in range(3):
        if random.random() < 0.5:
            row1, row2 = random.sample(range(3), 2)
            swap_rows_in_block(grid, block_row, row1, row2)
    
    #swap columns within blocks
    for block_col in range(3):
        if random.random() < 0.5:
            col1, col2 = random.sample(range(3), 2)
            swap_columns_in_block(grid, block_col, col1, col2)
    
    #randomly permute numbers
    if random.random() < 0.5:
        permute_numbers(grid)

def generate_solved_grid():
    grid = [[0 for _ in range(9)] for _ in range(9)]
    
    #fill diagonal boxes first (they are independent)
    for i in range(0, 9, 3):
        nums = list(range(1, 10))
        random.shuffle(nums)
        for row in range(3):
            for col in range(3):
                grid[row + i][col + i] = nums.pop()
    
    #solve rest of the grid
    solve_sudoku(grid)
    
    #apply random transformations
    apply_random_transformations(grid)
    
    return grid

def count_solutions(grid):
    #make a deep copy of the grid
    grid_copy = copy.deepcopy(grid)
    
    def count_solutions_helper(grid):
        empty = find_empty(grid)
        if not empty:
            return 1
        
        row, col = empty
        count = 0
        
        for num in range(1, 10):
            if is_valid(grid, row, col, num):
                grid[row][col] = num
                count += count_solutions_helper(grid)
                grid[row][col] = 0
                if count > 1:  # if more than one solution found
                    return count
        
        return count
    
    return count_solutions_helper(grid_copy)

def generate_puzzle(difficulty=40):
    solution = generate_solved_grid()
    puzzle = copy.deepcopy(solution)
    
    cells = [(i, j) for i in range(9) for j in range(9)]
    random.shuffle(cells)
    
    for i, j in cells:
        if len(cells) <= difficulty:
            break
            
        temp = puzzle[i][j]
        puzzle[i][j] = 0
        
        if count_solutions(puzzle) > 1:
            puzzle[i][j] = temp
        else:
            cells.remove((i, j))
    
    return puzzle, solution

def print_grid(grid):
    for i in range(9):
        if i % 3 == 0 and i != 0:
            print("- - - - - - - - - - - -")
        for j in range(9):
            if j % 3 == 0 and j != 0:
                print("|", end=" ")
            if j == 8:
                print(grid[i][j])
            else:
                print(str(grid[i][j]) + " ", end="")

def get_hint(puzzle, solution): #returns a random hint from the solution -- not in the puzzle
    empty_cells = []
    for i in range(9):
        for j in range(9):
            if puzzle[i][j] == 0:
                empty_cells.append((i, j, solution[i][j]))
    
    if not empty_cells:
        return None
    
    # Return a random empty cell and its solution
    return random.choice(empty_cells)

@app.route('/api/generate', methods=['GET'])
def api_generate():
    difficulty = request.args.get('difficulty', default=40, type=int)
    puzzle, solution = generate_puzzle(difficulty)
    return jsonify({
        'puzzle': puzzle,
        'solution': solution
    })

@app.route('/api/hint', methods=['POST'])
def api_hint():
    data = request.get_json()
    puzzle = data.get('puzzle')
    solution = data.get('solution')
    
    if not puzzle or not solution:
        return jsonify({'error': 'Puzzle and solution are required'}), 400
    
    hint = get_hint(puzzle, solution)
    if hint:
        row, col, num = hint
        return jsonify({
            'row': row,
            'col': col,
            'number': num
        })
    return jsonify({'error': 'No hints available'}), 404

if __name__ == "__main__":
    app.run(debug=True, port=5000)
