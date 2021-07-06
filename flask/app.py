from flask import Flask, render_template, jsonify, g, redirect
from flask_oidc import OpenIDConnect

import json
import logging
import os
import requests

logging.basicConfig(level=logging.DEBUG)

version = "0.1"
app = Flask(__name__)
app.config['JSONIFY_PRETTYPRINT_REGULAR'] = False

app.config.update({
    'SECRET_KEY': 'SomethingNotEntirelySecret',
    'TESTING': True,
    'DEBUG': True,
    'OIDC_CLIENT_SECRETS': '/code/secrets/client_secrets.json',
    'OIDC_ID_TOKEN_COOKIE_SECURE': False,
    'OIDC_REQUIRE_VERIFIED_EMAIL': False,
    'OIDC_OPENID_REALM': 'wireguard',
    'OIDC_ID_TOKEN_COOKIE_NAME': 'oidc_token'
})
oidc = OpenIDConnect(app)

def get_token ():
    url = 'https://vault.dockr.life/v1/wire/data/peer1'
    token_value = json.loads(open("/code/secrets/vault_token.json", "rb").read())
    headers = {'x-vault-token': token_value["root_token"]}
    resp = requests.get(url, headers=headers).json()
    peer = resp["data"]["data"]["peer1"]
    return peer

@app.route('/healthz')
def health_check():
    return jsonify({'flask': 'up'}), 200

@app.route('/')
def index():
    if oidc.user_loggedin:
        logged_in='true'
        zusername=oidc.user_getfield('preferred_username')
    else:
        logged_in='false'
        zusername=''

    peer = get_token()

    return render_template('index.html', logged_in=logged_in, username=zusername, code=peer)

@app.route('/login')
@oidc.require_login
def login():
    return redirect('/')

@app.route('/logout')
def logout():
    oidc.logout()
    return redirect('/')

@app.route('/api', methods=['POST'])
@oidc.accept_token(require_token=True)
def hello_api():
    peer = get_token()
    return json.dumps({'key': peer})

if __name__ == '__main__':
    app.run(host='0.0.0.0',debug=True)