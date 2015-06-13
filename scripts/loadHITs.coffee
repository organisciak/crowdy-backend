#
# Load a HIT file from JSON. See data/example-image-hit.json for example.
# JSON needs to be formatting more or less as it goes into Mongo except
# the items.

mongoose = require('mongoose')
Hit = require('../models/hit')

# Load JSON from first argument
path = require('path')
patharg = process.argv[2]
if (!patharg) then return console.error("No file specified.")
filepath = path.resolve(process.cwd(), patharg)

inputHIT = require(filepath)
console.log(inputHIT)

mongoose.connect('mongodb://localhost/test')
db = mongoose.connection
db.on('error', console.error.bind(console, 'connection error:'))

db.once('open', (callback) ->
    hit = new Hit(inputHIT)

    hit.save((err, res) ->
        if (err) then console.error(err)
        console.log("HIT saved")
        console.log(res)
    )
)
