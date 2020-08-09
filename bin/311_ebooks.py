

import markovify #https://github.com/jsvine/markovify
import sqlite3 #to read db

# Open the db
conn = sqlite3.connect('requests.sqlite')
c = conn.cursor()

def get_descriptions():
    c.execute('SELECT description FROM requests')
    data = c.fetchall()
    return(data)

# Get descriptions and convert to strings from tuples
b = ["".join(str(x)) for x in get_descriptions()]

# Build the model.
text_model = markovify.Text(b)

# Print three randomly-generated sentences of no more than 280 characters
for i in range(3):
    print(text_model.make_short_sentence(280))
