# Payments Service
from flask import Flask, request, jsonify
import uuid
import datetime
import os

app = Flask(__name__)

@app.route('/health', methods=['GET'])
def health():
    return jsonify({'status': 'healthy', 'service': 'payments'})

@app.route('/ready', methods=['GET'])
def ready():
    return jsonify({'status': 'ready', 'service': 'payments'})

@app.route('/payments', methods=['POST'])
def create_payment():
    data = request.get_json()
    payment = {
        'paymentId': str(uuid.uuid4()),
        'orderId': data.get('orderId'),
        'amount': data.get('amount'),
        'status': 'completed',
        'createdAt': datetime.datetime.now().isoformat()
    }
    return jsonify(payment), 201

@app.route('/payments', methods=['GET'])
def list_payments():
    payments = [{
        'paymentId': str(uuid.uuid4()),
        'orderId': 'order-123',
        'amount': 99.99,
        'status': 'completed',
        'createdAt': datetime.datetime.now().isoformat()
    }]
    return jsonify(payments)

if __name__ == '__main__':
    port = int(os.getenv('PORT', 8080))
    app.run(host='0.0.0.0', port=port)
