# ResQ Backend Server

This is the backend server for the ResQ emergency response application. It provides endpoints for reverse geocoding and building information.

## Setup

1. Create a virtual environment:
```bash
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

2. Install dependencies:
```bash
pip install -r requirements.txt
```

3. Create a `.env` file (optional):
```
GEOCODING_API_KEY=your_api_key_here  # Optional, using free Nominatim for now
PORT=55928  # Optional, defaults to 55928
```

## Running the Server

```bash
python app.py
```

The server will start on port 55928 by default.

## API Endpoints

### 1. Get Address from Coordinates
- **URL:** `/address`
- **Method:** `POST`
- **Data:**
  ```json
  {
    "lat": 37.4219999,
    "long": -122.0840575
  }
  ```
- **Response:**
  ```json
  [
    {
      "address": "1600 Amphitheatre Parkway, Mountain View, CA 94043"
    }
  ]
  ```

### 2. Get Building Information
- **URL:** `/building`
- **Method:** `GET`
- **Query Parameters:**
  - `lat`: Latitude
  - `long`: Longitude
- **Response:**
  ```json
  [
    {
      "description": "Building description",
      "address": "Building address"
    }
  ]
  ``` 