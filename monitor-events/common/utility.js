const { subscribe } = require("../controller/event");

class Utility
{
    static sleep(ms) {
        return new Promise((resolve) => {
            setTimeout(resolve, ms);
        });
    }
    static addDays = function(date, days) {
        date.setDate(date.getDate() + days);
        return date;
    }
    static getRandomInt(min, max) {
        min = Math.ceil(min);
        max = Math.floor(max);
        return Math.floor(Math.random() * (max - min) + min);
    }
    static addRandomDays = function(date, dayRange) {
        date.setDate(date.getDate() + this.getRandomInt(0, dayRange));
        return date;
    }
    static subRandomDays = function(date, dayRange) {
        date.setDate(date.getDate() - this.getRandomInt(0, dayRange));
        return date;
    }
    static getRandomDatePast(dayRange) {
        var date = new Date();
        date.setDate(date.getDate() - this.getRandomInt(0, dayRange));
        return date;
    }
    static getRandomTxId(min, max) {
        min = Math.ceil(min);
        max = Math.floor(max);
        return Math.floor(Math.random() * (max - min) + min) + '.' + Math.floor(Math.random() * (max - min) + min) + '.' + Math.floor(Math.random() * (max - min) + min) ;
    }
    static getYearId(date = new Date()) {
        return date.getFullYear().toString() + ((date.getMonth() + 1) < 10, (date.getMonth() + 1).toString(), '0' + (date.getMonth() + 1).toString()) + (date.getDate() < 10, date.getDate().toString(), '0' + date.getDate().toString());
    }
    static getDate(date = new Date()) {
        return (date.getDate() < 10, date.getDate().toString(), '0' + date.getDate().toString());
    }
    static getId(length) {
        const min = 0;
        const max = Math.pow(10,length);
        let val = (Math.floor(Math.random() * (max - min) + min)).toString();
        return val.padStart(length - val.length,'0');
    }
    static getFields(obj, childPrefix = '') {
        try {
            var fields = [];
            for (let [key, value] of Object.entries(obj)) {
                if(key == 'Records')//skip
                    continue;
                else if (value != undefined && (typeof value === "object" && !Array.isArray(value))) {
                    fields = fields.concat(this.getFields(value, (childPrefix.length == 0 ? key : childPrefix + '.' + key)));
                }
                else {
                    console.log(key + ' : ' + value);
                    fields.push({ Key: (childPrefix.length == 0 ? key : childPrefix + '.' + key), Value: value });
                }
            }
            return fields;
        }
        catch (err) {
            console.log('Error getFields: ' + err);
        }
    }
}

module.exports = Utility;