from flask import Flask, request, jsonify
from flask_cors import CORS
import requests
import os
from dotenv import load_dotenv

load_dotenv()

app = Flask(__name__)
CORS(app)  # Enable CORS for all routes

# Get your API key from environment variables
GEOCODING_API_KEY = os.getenv('GEOCODING_API_KEY', '')

@app.route('/address', methods=['POST'])
def get_address():
    try:
        data = request.get_json()
        lat = data.get('lat')
        long = data.get('long')
        
        print(f"Received coordinates: lat={lat}, long={long}")
        
        if lat is None or long is None:
            print("Missing lat/long parameters")
            return jsonify({'error': 'Missing lat/long parameters'}), 400

        # Use Nominatim API (free, no API key required) for development
        nominatim_url = 'https://nominatim.openstreetmap.org/reverse'
        params = {
            'lat': str(lat),
            'lon': str(long),
            'format': 'json',
            'zoom': 18,  # Highest zoom level for most detailed address
            'addressdetails': 1
        }
        headers = {
            'User-Agent': 'ResQ Emergency App/1.0',
            'Accept-Language': 'en-US,en;q=0.9'
        }
        
        print(f"Making request to Nominatim: {nominatim_url}")
        print(f"Parameters: {params}")
        
        response = requests.get(
            nominatim_url,
            params=params,
            headers=headers
        )
        
        print(f"Nominatim response status: {response.status_code}")
        print(f"Nominatim response: {response.text}")
        
        if response.status_code == 200:
            location_data = response.json()
            # Try to construct a more readable address
            if 'address' in location_data:
                addr = location_data['address']
                address_parts = []
                
                # Add house number and street
                if 'house_number' in addr and 'road' in addr:
                    address_parts.append(f"{addr['house_number']} {addr['road']}")
                elif 'road' in addr:
                    address_parts.append(addr['road'])
                
                # Add city/town/village
                for key in ['city', 'town', 'village', 'suburb']:
                    if key in addr:
                        address_parts.append(addr[key])
                        break
                
                # Add state and country
                if 'state' in addr:
                    address_parts.append(addr['state'])
                if 'country' in addr:
                    address_parts.append(addr['country'])
                
                formatted_address = ', '.join(address_parts)
                if formatted_address:
                    address = formatted_address
                else:
                    address = location_data.get('display_name', 'Address not found')
            else:
                address = location_data.get('display_name', 'Address not found')
            
            print(f"Returning address: {address}")
            return jsonify([{'address': address}])
        else:
            print(f"Address lookup failed with status {response.status_code}")
            return jsonify([{'address': 'Address lookup failed'}])

    except Exception as e:
        print(f'Error in get_address: {e}')
        return jsonify([{'address': 'Error getting address'}])

@app.route('/building', methods=['GET'])
def get_building_info():
    try:
        lat = request.args.get('lat')
        long = request.args.get('long')
        
        if lat is None or long is None:
            return jsonify({'error': 'Missing lat/long parameters'}), 400

        # For now, return a simple response
        # TODO: Integrate with a building information database
        return jsonify([{
            'description': 'Building information not available',
            'address': 'Address lookup not implemented'
        }])

    except Exception as e:
        print(f'Error in get_building_info: {e}')
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    port = int(os.getenv('PORT', 55928))
    app.run(host='0.0.0.0', port=port, debug=True) 