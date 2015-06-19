# Load pin items from JSON to MongoDB.
# If data is in csv, use csvkit's csvjson function
# e.g. 
#   coffee scripts/loadPinsFromCSV.coffee \
#       --pin-data data/sample-PinData.coffee \
#       --pin-join-data data/sample-PinJoinData.coffee

mongoose = require 'mongoose'
argv = require('yargs').argv
path = require 'path'
async = require 'async'
_ = require 'underscore'

Pin = require '../models/pin'

# Load Pin Data
if !argv.pinData then return console.error("No file specified.")
filepath = path.resolve(process.cwd(), argv.pinData)
pinData = require(filepath)


processPin = (pin) ->
  # Prepare Pin in proper format
  newPin = _.clone(pin)
  for val in ['id', 'image', 'image60', 'image236', 'domain', 'source', 'pin_join']
    delete newPin[val]
  newPin.image = {
    full: pin.image,
    '60': pin.image60,
    '236': pin.image236
  }
  newPin._id = pin.id
  newPin.meta = { source: pin.source, domain: pin.domain }
  newPin.pin_join = { id: pin.pin_join }

  # Make pin into instance of Mongoose model and save
  pinInstance = new Pin(newPin)
  pinInstance.save((err, res) ->
    if (err) then return console.error(err)
    console.log(res)
  )

db = mongoose.createConnection('mongodb://localhost/test')
db.on('error', console.error.bind(console, 'connection error:'))

db.once('open', (callback) ->
    async.each(pinData, processPin, (err) -> console.error(err))
)

## If PinJoinData is available
#addPinJoinData = () ->
    #filepath = path.resolve(process.cwd(), argv.pinJoinData)
