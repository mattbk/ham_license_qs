

import markovify #https://github.com/jsvine/markovify
import sqlite3 #to read db
from mastodon import Mastodon
from configparser import ConfigParser
import os.path

# Open the db
conn = sqlite3.connect('requests.sqlite')
c = conn.cursor()

def get_descriptions():
    c.execute('SELECT description FROM requests')
    data = c.fetchall()
    return(data)

# Get descriptions and convert to strings from tuples
b = ["".join(str(x).replace("\\r\\n","")) for x in get_descriptions()]

# Build the model.
text_model = markovify.Text(b)

# Print three randomly-generated sentences of no more than 280 characters
#for i in range(3):
#    print(text_model.make_short_sentence(280))

# Next up use this to toot: https://github.com/halcy/Mastodon.py

# parse existing file
config = ConfigParser()
config.read('auth.ini')

# read values from a section
server = config.get('hackgfk_311_ebooks', 'server')
email = config.get('hackgfk_311_ebooks', 'email')
password = config.get('hackgfk_311_ebooks', 'password')

# Register the app (once)
if not os.path.isfile('hackgfk_311_ebooks_clientcred.secret'):
    Mastodon.create_app(
         'hackgfk_311_ebooks',
         api_base_url = server,
         to_file = 'hackgfk_311_ebooks_clientcred.secret'
    )

# Log in
mastodon = Mastodon(
    client_id = 'hackgfk_311_ebooks_clientcred.secret',
    api_base_url = server,
)
mastodon.log_in(
    email,
    password,
    to_file = 'hackgfk_311_ebooks_usercred.secret'
)

# Send toot
toot = text_model.make_short_sentence(280)
print(toot)
mastodon.toot(toot)
