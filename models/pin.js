var mongoose = require('mongoose');
var db = mongoose.createConnection('mongodb://localhost/test');

var pinSchema = mongoose.Schema({
    _id:Number,
    url:String,
    description:String,
    type:String,
    title:String,
    image: {
        full:String,
        '60':String,
        '236':String
    },
    likes:Number,
    repins:Number,
    meta: {
        source: String,
        domain: String
    },
    price: Number,
    price_currency: String,
    created: Date,
    comment_count: Number,
    place: String,
    board: Number,
    pinner: Number,
    is_banned: Boolean,
    is_repin: Boolean,
    via_pinner: Number,
    pin_join: {
        id: String,
        seo_description: String,
        visual_annotation: String,
        canonical_pin: Number, //Just keep the id of the canonical pin
    }
});

var Pin = db.model('Pin', pinSchema);

module.exports = Pin;
