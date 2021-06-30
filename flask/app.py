from flask import Flask, render_template, jsonify, g
from flask_oidc import OpenIDConnect

import json
import logging
import os

logging.basicConfig(level=logging.DEBUG)


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
        return ('Hello, %s, <a href="/login">See login</a> '
                '<a href="/logout">Log out</a>') % \
            oidc.user_getfield('preferred_username')
    else:
        return render_template('login.html')


@app.route('/login')
@oidc.require_login
def login():
    return 'Welcome %s' % oidc.user_getfield('preferred_username')


@app.route('/api')
@oidc.accept_token(True, ['openid'])
def hello_api():
    return json.dumps({'hello': 'Welcome %s' % g.oidc_token_info['sub']})


@app.route('/logout')
def logout():
    oidc.logout()
    return 'Hi, you have been logged out! <a href="/">Return</a>'


if __name__ == '__main__':
    app.run(host='0.0.0.0',debug=True)