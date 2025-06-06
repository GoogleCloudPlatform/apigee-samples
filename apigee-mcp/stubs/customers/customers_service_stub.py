# Copyright 2025 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
from flask import Flask, request, jsonify
import uuid
from datetime import datetime, timezone

app = Flask(__name__)

# In-memory data stores
customers_db = {}
addresses_db = {}  # { customer_id: { address_id: address_object } }
payment_methods_db = {}  # { customer_id: { payment_method_id: pm_object } }

def initialize_data():
    """Populates the in-memory stores with some initial data."""
    global customers_db, addresses_db, payment_methods_db

    # Customer 1
    # cust1_id = str(uuid.uuid4())
    cust1_id = "1234"  # Use a known ID
    cust1 = {
        "customerId": cust1_id,
        "username": "janedoe",
        "email": "jane.doe@example.com",
        "firstName": "Jane",
        "lastName": "Doe",
        "registrationDate": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")
    }
    customers_db[cust1_id] = cust1
    addresses_db[cust1_id] = {}
    payment_methods_db[cust1_id] = {}

    # Address 1 for Customer 1
    addr1_id = str(uuid.uuid4())
    addr1 = {
        "addressId": addr1_id,
        "streetAddress": "123 Main St",
        "city": "Anytown",
        "state": "CA",
        "zipCode": "90210",
        "country": "USA"
    }
    addresses_db[cust1_id][addr1_id] = addr1

    # Address 2 for Customer 1
    addr2_id = str(uuid.uuid4())
    addr2 = {
        "addressId": addr2_id,
        "streetAddress": "456 Oak Ave",
        "city": "Otherville",
        "state": "NY",
        "zipCode": "10001",
        "country": "USA"
    }
    addresses_db[cust1_id][addr2_id] = addr2

    # Payment Method 1 for Customer 1 (references addr1_id)
    pm1_id = str(uuid.uuid4())
    pm1 = {
        "paymentMethodId": pm1_id,
        "cardholderName": "Jane Doe",
        "cardNumber": "**** **** **** 1234",  # Masked
        "expirationDate": "2025-12-31",
        "billingAddressId": addr1_id
    }
    payment_methods_db[cust1_id][pm1_id] = pm1

    # Customer 2
    cust2_id = str(uuid.uuid4())
    cust2 = {
        "customerId": cust2_id,
        "username": "bobsmith",
        "email": "bob.smith@example.com",
        "firstName": "Bob",
        "lastName": "Smith",
        "registrationDate": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")
    }
    customers_db[cust2_id] = cust2
    addresses_db[cust2_id] = {}
    payment_methods_db[cust2_id] = {}

initialize_data()

def make_error(status_code, code, message, field=None):
    """Helper function to create standardized error responses."""
    response_data = {"code": code, "message": message}
    if field:
        response_data["field"] = field
    return jsonify(response_data), status_code

# --- Customer Operations ---

@app.route('/customers', methods=['POST'])
def create_customer():
    if not request.is_json:
        return make_error(400, "INVALID_CONTENT_TYPE", "Request must be application/json")
    data = request.get_json()

    required_fields = ["username", "password", "email", "firstName", "lastName"]
    for field in required_fields:
        if field not in data or not data[field]:
            return make_error(400, "MISSING_FIELD", f"Missing required field: {field}", field=field)

    # Check for username uniqueness (optional, but good practice)
    if any(c['username'] == data['username'] for c in customers_db.values()):
        return make_error(400, "USERNAME_EXISTS", "Username already exists", field="username")
    if any(c['email'] == data['email'] for c in customers_db.values()):
        return make_error(400, "EMAIL_EXISTS", "Email already exists", field="email")

    customer_id = str(uuid.uuid4())
    new_customer = {
        "customerId": customer_id,
        "username": data["username"],
        "email": data["email"],
        "firstName": data["firstName"],
        "lastName": data["lastName"],
        "registrationDate": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")
    }
    customers_db[customer_id] = new_customer
    addresses_db[customer_id] = {}
    payment_methods_db[customer_id] = {}
    return jsonify(new_customer), 201

@app.route('/customers/<string:customerId>', methods=['GET'])
def get_customer_by_id(customerId):
    customer = customers_db.get(customerId)
    if not customer:
        return make_error(404, "CUSTOMER_NOT_FOUND", "Customer not found")
    return jsonify(customer), 200

@app.route('/customers/<string:customerId>', methods=['PUT'])
def update_customer(customerId):
    customer = customers_db.get(customerId)
    if not customer:
        return make_error(404, "CUSTOMER_NOT_FOUND", "Customer not found")

    if not request.is_json:
        return make_error(400, "INVALID_CONTENT_TYPE", "Request must be application/json")
    data = request.get_json()
    if not data:
        return make_error(400, "EMPTY_REQUEST_BODY", "Request body cannot be empty for update")

    # Update allowed fields
    if "email" in data:
        # Optional: Check if new email is already taken by another user
        if data["email"] != customer["email"] and any(c['email'] == data['email'] for c_id, c in customers_db.items() if c_id != customerId):
            return make_error(400, "EMAIL_EXISTS", "Email already exists", field="email")
        customer["email"] = data["email"]
    if "firstName" in data:
        customer["firstName"] = data["firstName"]
    if "lastName" in data:
        customer["lastName"] = data["lastName"]
    if "username" in data:
         # Optional: Check if new username is already taken by another user
        if data["username"] != customer["username"] and any(c['username'] == data['username'] for c_id, c in customers_db.items() if c_id != customerId):
            return make_error(400, "USERNAME_EXISTS", "Username already exists", field="username")
        customer["username"] = data["username"]

    customers_db[customerId] = customer
    return jsonify(customer), 200

@app.route('/customers/<string:customerId>', methods=['DELETE'])
def delete_customer(customerId):
    if customerId not in customers_db:
        return make_error(404, "CUSTOMER_NOT_FOUND", "Customer not found")

    del customers_db[customerId]
    if customerId in addresses_db:
        del addresses_db[customerId]
    if customerId in payment_methods_db:
        del payment_methods_db[customerId]

    return '', 204

# --- Address Operations ---

@app.route('/customers/<string:customerId>/addresses', methods=['POST'])
def add_customer_address(customerId):
    if customerId not in customers_db:
        return make_error(404, "CUSTOMER_NOT_FOUND", "Customer not found")

    if not request.is_json:
        return make_error(400, "INVALID_CONTENT_TYPE", "Request must be application/json")
    data = request.get_json()

    required_fields = ["streetAddress", "city", "state", "zipCode", "country"]
    for field in required_fields:
        if field not in data or not data[field]:
            return make_error(400, "MISSING_FIELD", f"Missing required field: {field}", field=field)

    address_id = str(uuid.uuid4())
    new_address = {
        "addressId": address_id,
        "streetAddress": data["streetAddress"],
        "city": data["city"],
        "state": data["state"],
        "zipCode": data["zipCode"],
        "country": data["country"]
    }
    addresses_db[customerId][address_id] = new_address
    return jsonify(new_address), 201

@app.route('/customers/<string:customerId>/addresses', methods=['GET'])
def get_customer_addresses(customerId):
    if customerId not in customers_db:
        return make_error(404, "CUSTOMER_NOT_FOUND", "Customer not found")

    customer_addresses = list(addresses_db.get(customerId, {}).values())

    page_size = request.args.get('pageSize', type=int, default=10)
    page_token_str = request.args.get('pageToken', type=str)

    start_index = 0
    if page_token_str:
        try:
            start_index = int(page_token_str)
            if start_index < 0: raise ValueError()
        except ValueError:
            return make_error(400, "INVALID_PAGE_TOKEN", "Invalid pageToken format.")

    end_index = start_index + page_size
    paginated_addresses = customer_addresses[start_index:end_index]

    next_page_token = None
    if end_index < len(customer_addresses):
        next_page_token = str(end_index)

    response_data = {
        "data": paginated_addresses
    }
    if next_page_token:
        response_data["nextPageToken"] = next_page_token

    return jsonify(response_data), 200

@app.route('/customers/<string:customerId>/addresses/<string:addressId>', methods=['GET'])
def get_customer_address(customerId, addressId):
    if customerId not in customers_db:
        return make_error(404, "CUSTOMER_NOT_FOUND", "Customer not found")
    
    address = addresses_db.get(customerId, {}).get(addressId)
    if not address:
        return make_error(404, "ADDRESS_NOT_FOUND", "Address not found")
    
    return jsonify(address), 200

@app.route('/customers/<string:customerId>/addresses/<string:addressId>', methods=['PUT'])
def update_customer_address(customerId, addressId):
    if customerId not in customers_db:
        return make_error(404, "CUSTOMER_NOT_FOUND", "Customer not found")
    
    customer_addrs = addresses_db.get(customerId, {})
    if addressId not in customer_addrs:
        return make_error(404, "ADDRESS_NOT_FOUND", "Address not found")

    if not request.is_json:
        return make_error(400, "INVALID_CONTENT_TYPE", "Request must be application/json")
    data = request.get_json()
    if not data:
         return make_error(400, "EMPTY_REQUEST_BODY", "Request body cannot be empty for update")

    # Per OpenAPI spec, requestBody schema is shippingaddress, which has required fields.
    # The addressId in the body is ignored; path parameter is canonical.
    required_fields = ["streetAddress", "city", "state", "zipCode", "country"]
    for field in required_fields:
        if field not in data: # Value can be empty string if allowed by type, but key must be present
            return make_error(400, "MISSING_FIELD", f"Missing required field for update: {field}", field=field)

    updated_address = {
        "addressId": addressId, # Keep original addressId
        "streetAddress": data["streetAddress"],
        "city": data["city"],
        "state": data["state"],
        "zipCode": data["zipCode"],
        "country": data["country"]
    }
    customer_addrs[addressId] = updated_address
    return jsonify(updated_address), 200

@app.route('/customers/<string:customerId>/addresses/<string:addressId>', methods=['DELETE'])
def delete_customer_address(customerId, addressId):
    if customerId not in customers_db:
        return make_error(404, "CUSTOMER_NOT_FOUND", "Customer not found")

    customer_addrs = addresses_db.get(customerId, {})
    if addressId not in customer_addrs:
        return make_error(404, "ADDRESS_NOT_FOUND", "Address not found")

    # Check if this address is used by any payment method
    customer_pms = payment_methods_db.get(customerId, {})
    for pm_id, pm_details in customer_pms.items():
        if pm_details.get("billingAddressId") == addressId:
            return make_error(400, "ADDRESS_IN_USE", 
                              f"Address is in use by payment method {pm_id} and cannot be deleted.")

    del customer_addrs[addressId]
    return '', 204

# --- Payment Method Operations ---

@app.route('/customers/<string:customerId>/paymentMethods', methods=['POST'])
def add_customer_payment_method(customerId):
    if customerId not in customers_db:
        return make_error(404, "CUSTOMER_NOT_FOUND", "Customer not found")

    if not request.is_json:
        return make_error(400, "INVALID_CONTENT_TYPE", "Request must be application/json")
    data = request.get_json()

    required_fields = ["cardholderName", "cardNumber", "expirationDate", "billingAddressId"]
    for field in required_fields:
        if field not in data or not data[field]:
            return make_error(400, "MISSING_FIELD", f"Missing required field: {field}", field=field)

    billing_address_id = data["billingAddressId"]
    if billing_address_id not in addresses_db.get(customerId, {}):
        return make_error(400, "INVALID_BILLING_ADDRESS", 
                          "Billing address ID not found for this customer.", field="billingAddressId")

    pm_id = str(uuid.uuid4())
    new_pm = {
        "paymentMethodId": pm_id,
        "cardholderName": data["cardholderName"],
        "cardNumber": data["cardNumber"], # Should be masked in a real app before storing
        "expirationDate": data["expirationDate"],
        "billingAddressId": billing_address_id
    }
    payment_methods_db[customerId][pm_id] = new_pm
    return jsonify(new_pm), 201

@app.route('/customers/<string:customerId>/paymentMethods', methods=['GET'])
def get_customer_payment_methods(customerId):
    if customerId not in customers_db:
        return make_error(404, "CUSTOMER_NOT_FOUND", "Customer not found")

    customer_pms = list(payment_methods_db.get(customerId, {}).values())

    page_size = request.args.get('pageSize', type=int, default=10)
    page_token_str = request.args.get('pageToken', type=str)

    start_index = 0
    if page_token_str:
        try:
            start_index = int(page_token_str)
            if start_index < 0: raise ValueError()
        except ValueError:
            return make_error(400, "INVALID_PAGE_TOKEN", "Invalid pageToken format.")

    end_index = start_index + page_size
    paginated_pms = customer_pms[start_index:end_index]

    next_page_token = None
    if end_index < len(customer_pms):
        next_page_token = str(end_index)

    response_data = {
        "data": paginated_pms
    }
    if next_page_token:
        response_data["nextPageToken"] = next_page_token
    
    return jsonify(response_data), 200

@app.route('/customers/<string:customerId>/paymentMethods/<string:paymentMethodId>', methods=['GET'])
def get_customer_payment_method(customerId, paymentMethodId):
    if customerId not in customers_db:
        return make_error(404, "CUSTOMER_NOT_FOUND", "Customer not found")
    
    pm = payment_methods_db.get(customerId, {}).get(paymentMethodId)
    if not pm:
        return make_error(404, "PAYMENT_METHOD_NOT_FOUND", "Payment method not found")
        
    return jsonify(pm), 200

@app.route('/customers/<string:customerId>/paymentMethods/<string:paymentMethodId>', methods=['PUT'])
def update_customer_payment_method(customerId, paymentMethodId):
    if customerId not in customers_db:
        return make_error(404, "CUSTOMER_NOT_FOUND", "Customer not found")
    
    customer_pms = payment_methods_db.get(customerId, {})
    if paymentMethodId not in customer_pms:
        return make_error(404, "PAYMENT_METHOD_NOT_FOUND", "Payment method not found")

    if not request.is_json:
        return make_error(400, "INVALID_CONTENT_TYPE", "Request must be application/json")
    data = request.get_json()
    if not data:
         return make_error(400, "EMPTY_REQUEST_BODY", "Request body cannot be empty for update")

    # Per OpenAPI spec, requestBody schema is PaymentMethod, which has required fields.
    # The paymentMethodId in the body is ignored; path parameter is canonical.
    required_fields = ["cardholderName", "cardNumber", "expirationDate", "billingAddressId"]
    for field in required_fields:
        if field not in data:
            return make_error(400, "MISSING_FIELD", f"Missing required field for update: {field}", field=field)

    billing_address_id = data["billingAddressId"]
    if billing_address_id not in addresses_db.get(customerId, {}):
        return make_error(400, "INVALID_BILLING_ADDRESS", 
                          "Billing address ID not found for this customer.", field="billingAddressId")

    updated_pm = {
        "paymentMethodId": paymentMethodId, # Keep original ID
        "cardholderName": data["cardholderName"],
        "cardNumber": data["cardNumber"],
        "expirationDate": data["expirationDate"],
        "billingAddressId": billing_address_id
    }
    customer_pms[paymentMethodId] = updated_pm
    return jsonify(updated_pm), 200

@app.route('/customers/<string:customerId>/paymentMethods/<string:paymentMethodId>', methods=['DELETE'])
def delete_customer_payment_method(customerId, paymentMethodId):
    if customerId not in customers_db:
        return make_error(404, "CUSTOMER_NOT_FOUND", "Customer not found")

    customer_pms = payment_methods_db.get(customerId, {})
    if paymentMethodId not in customer_pms:
        return make_error(404, "PAYMENT_METHOD_NOT_FOUND", "Payment method not found")

    del customer_pms[paymentMethodId]
    return '', 204


@app.route('/', methods=['GET'])
def health_check():
    return jsonify({
        "status": "healthy",
        "message": "Customer API stub is running.",
        "customers_count": len(customers_db),
        "addresses_count_total": sum(len(v) for v in addresses_db.values()),
        "payment_methods_count_total": sum(len(v) for v in payment_methods_db.values())
    }), 200


if __name__ == '__main__':
    # Note: For development only. Use a proper WSGI server for production.
    app.run(debug=True, port=5001)