# Load a properly formatted JSON to MongoDB from the command line, to the table
# specified
# e.g.
#   coffee scripts/saveJSONtoMongo.coffee \
#     --model taskset
#     --json data/example-taskSet.json
#

mongoose = require 'mongoose'
path = require 'path'
config = require 'config'
_ = require 'lodash'
async = require 'async'
db_server = 'mongodb://' + config.get('db.host') + '/' + config.get('db.name')

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
mongoose.connect db_server
db = mongoose.connection
db.on('error', console.error.bind(console, 'connection error:'))

saveItem = (item, callback) ->
  instance = new Model(item)
  instance.save((err, res) ->
    if (err) then return callback(err)
    console.log "Successfully saved"
    console.log res
    callback()
  )

db.once('open', (callback) ->
  if !_.isArray(input)
    input = [input]
  async.each(input, saveItem, (err) ->
    if err then console.error err
    db.close()
  )
)
