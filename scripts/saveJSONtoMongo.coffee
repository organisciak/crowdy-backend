# Load a properly formatted JSON to MongoDB from the command line, to the table
# specified
# e.g.
#   coffee scripts/saveJSONtoMongo.coffee \
#     --model taskset
#     --json data/example-taskSet.json
#

mongoose = require 'mongoose'
path = require 'path'

# Load Args
argv = require('yargs')
      .usage('Usage: $0 --model [model] --json [file]')
      .demand(['model','json'])
      .argv

# Load Model
Model = require '../models/' + argv.model

# Load JSON
filepath = path.resolve(process.cwd(), argv.json)
input = require(filepath)

# Save to DB
mongoose.connect('mongodb://localhost/test')
db = mongoose.connection
db.on('error', console.error.bind(console, 'connection error:'))

db.once('open', (callback) ->
  instance = new Model(input)
  instance.save((err, res) ->
    if (err) then return console.error(err)
    console.log "Successfully saved"
    console.log res
  )
)
