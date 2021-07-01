from flask import Flask, render_template, jsonify, g, redirect
from flask_oidc import OpenIDConnect

import json
import logging
import os
import base64

logging.basicConfig(level=logging.DEBUG)

image_file=open("peer1.conf", "rb")

version = "0.1"
app = Flask(__name__)
app.config['JSONIFY_PRETTYPRINT_REGULAR'] = False

app.config.update({
    'SECRET_KEY': 'SomethingNotEntirelySecret',
    'TESTING': True,
    'DEBUG': True,
    'OIDC_CLIENT_SECRETS': 'client_secrets.json',
    'OIDC_ID_TOKEN_COOKIE_SECURE': False,
    'OIDC_REQUIRE_VERIFIED_EMAIL': False,
    'OIDC_OPENID_REALM': 'https://flask.dockr.life/oidc_callback'
})
oidc = OpenIDConnect(app)

@app.route('/healthz')
def health_check():
    return jsonify({'flask': 'up'}), 200

@app.route('/')
def index(server_name=None):
    if oidc.user_loggedin:
        logged_in='true'
    else:
        logged_in='false'
    return render_template('index.html', logged_in=logged_in, username='', code=base64.b64encode(open("peer1.conf", "rb").read()).decode('utf-8'))

@app.route('/login')
@oidc.require_login
def login():
    return redirect('/')

@app.route('/logout')
def logout():
    oidc.logout()
    return redirect('/')

@app.route('/api')
@oidc.accept_token(True, ['openid'])
def hello_api():
    return json.dumps({'hello': 'Welcome %s' % g.oidc_token_info['sub']})

if __name__ == '__main__':
    app.run(host='0.0.0.0',debug=True)