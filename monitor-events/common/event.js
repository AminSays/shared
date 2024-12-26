const faye = require('faye');
const AppError = require('../common/appError');
const Org = require('../common/orgAccess');
const Callout = require('../common/callout');

/*
  @author: Amin ur Rehman (GitHub: AminSays)
  @version: 1.0
  @name: EventUtility
  @description: Custom class to provide capabilities to subscribe to event, query audit trail and log files
*/
class EventUtility {
    static access_token = '';
    static subscriptions = [];
    static events = [];
    static client;

    /*
    @name: authorize
    @description: Function to authorize against a Salesforce Org
    @return: None
   */
    static async authorize() {
        if (this.client == undefined || this.client == null) {
            //review and update API version id to the latest supported
            this.client = new faye.Client(Org.OrgUrl() + '/cometd/56.0/');
            this.access_token = await Callout.authorize();
            this.client.setHeader('Authorization', 'OAuth ' + this.access_token);
        }
    }
    /*
    @name: sub
    @description: Function to subscribe to event channel
    @return: Boolean, if the subscription was successful or not
   */
    static async sub(channelName) {
        await this.authorize();
        if (this.isSubscribed(channelName) > -1) {
            //console.log('Found ' + channelName + ' at:' + index);
            console.log('Already subscribed to: ' + channelName);
            return true;
        }

        var thisRef = this;
        var subscription = this.client.subscribe(channelName, function (message) {
            try {
                console.log('Message recieved on: ' + channelName);
                message.channelName = channelName;
                if (message.payload.Records != undefined) {
                    message.payload.Records = "..removed..";
                }

                thisRef.addToEvents(message);
            }
            catch (err) { console.log(err) };
        });
        await subscription.then(function () {
            try {
                console.log('Subscribed to ' + subscription._channels);
                thisRef.addToSubscriptions(subscription);
            }
            catch (err) { console.log(err) };
        }).catch((reason) => {
            throw new Error(reason);
        });
    }
    /*
    @name: isSubscribed
    @description: Function to check if subscribed to an event
    @param: channelName, name of channel to check if its already subscribed
    @return: Boolean, if the subscribe was already subscribed or not
   */
    static isSubscribed(channelName) {
        return this.subscriptions.findIndex(subscription => { return subscription._channels == channelName });
    }
    /*
    @name: addToSubscriptions
    @description: Function to add channel to list of subscribed channels
    @param: subscription, subscription object
    @return: none
   */
    static addToSubscriptions(subscription) {
        this.subscriptions.push(subscription);
    }
    /*
    @name: addToEvents
    @description: Function add an event message to list of events received
    @param: subscription, subscription object
    @return: none
   */
    static addToEvents(message) {
        if (this.events.length >= 100) {
            this.events.shift();
        }
        this.events.push(message);
    }
    /*
    @name: clearEvents
    @description: Function to reset list of events received
    @return: none
   */
    static clearEvents() {
        this.events = [];
    }
    /*
    @name: unsub
    @description: Function add unsubscribe to a channel
    @param: channelName, name of channel to unsubscribe to
    @return: Boolean, if the unsubscribe was successful or not
   */
    static async unsub(channelName) {
        await this.authorize();
        var index = this.isSubscribed(channelName);
        if (index > -1) {
            this.subscriptions[index].cancel();
            this.subscriptions[index].unsubscribe();
            this.subscriptions.splice(index);
            console.log('Unsubscribed to ' + this.subscriptions[index]._channels);
        }
        else {
            console.log('Not subscribed to channel: ' + channelName);
        }
        return true;
    }
    /*
    @name: unsubAll
    @description: Function unscubscribe to all subscribed channels
    @return: none
   */
    static async unsubAll() {
        await this.authorize();
        this.subscriptions.forEach(subscription => {
            subscription.cancel();
            subscription.unsubscribe();
            console.log('Unsubscribed to ' + subscription._channels);
        });
        this.subscriptions = [];
        console.log('Unsubscribed to all.');
    }
    /*
    @name: getAuditTrail
    @description: Function get latest 100 Setup Audit trail entries
    @return: JSON list of setup audit trail entries
   */
    static async getAuditTrail() {
        try {
            const query = 'SELECT Id, Action, Section, CreatedDate, CreatedById, CreatedBy.Name, CreatedBy.Username, Display, DelegateUser, ResponsibleNamespacePrefix, CreatedByContext, CreatedByIssuer '
                + 'FROM SetupAuditTrail '
                + 'ORDER BY CreatedDate DESC '
                + 'LIMIT 100';
            const url = '/services/data/v56.0/query/?q=' + query;
            const res = await Callout.call(url, 'GET');
            return res;
        }
        catch (err) {
            throw new AppError(err, 'Failed to get Audit Trail.');
        }
    }
    /*
    @name: getLoginHistory
    @description: Function get latest 100 Login History entries
    @return: JSON list of Login History entries
   */
    static async getLoginHistory() {
        try {
            const query = 'SELECT Id, UserId, LoginTime, LoginType, SourceIp, LoginUrl, NetworkId, AuthenticationServiceId, LoginGeoId, TlsProtocol, CipherSuite, OptionsIsGet, OptionsIsPost, Browser, Platform, Status, Application, ClientVersion, ApiType, ApiVersion, CountryIso, AuthMethodReference '
                + 'FROM LoginHistory '
                + 'ORDER BY LoginTime DESC '
                + 'LIMIT 100';
            const url = '/services/data/v56.0/query/?q=' + query;
            const res = await Callout.call(url, 'GET');
            return res;
        }
        catch (err) {
            throw new AppError(err, 'Failed to get Audit Trail.');
        }
    }
    /*
    @name: getUsers
    @description: Function get all users
    @return: JSON list of Users
   */
    static async getUsers() {
        try {
            const query = 'SELECT Id, Username, LastName, FirstName, Name, Email, Country '
                + 'FROM User ';
            const url = '/services/data/v56.0/query/?q=' + query;
            const res = await Callout.call(url, 'GET');
            return res;
        }
        catch (err) {
            throw new AppError(err, 'Failed to get Users.');
        }
    }
    /*
    @name: getUsers
    @description: Function get latest 100 event log file entries
    @param: id, SFID of event log file entry
    @return: JSON list of Event log file entries
   */
    static async getLogs(id) {
        try {
            if (id == undefined || id == '') {
                const query = 'SELECT Id, CreatedDate, LastModifiedDate, EventType, Interval, LogDate, LogFileLength, LogFileContentType, ApiVersion, LogFileFieldNames, LogFileFieldTypes, LogFile '
                    + 'FROM EventLogFile '
                    + 'ORDER BY LastModifiedDate DESC '
                    + 'LIMIT 100';
                const url = '/services/data/v56.0/query/?q=' + query;
                const res = await Callout.call(url, 'GET');
                return res;
            }
            else {
                const url = '/services/data/v56.0/sobjects/EventLogFile/' + id + '/LogFile';
                const res = await Callout.call(url, 'GET');
                return res;
            }
        }
        catch (err) {
            throw new AppError(err, 'Failed to get Logs.');
        }
    }
    /*
    @name: postCaseEvent
    @description: Function publish a custom platform Case Event
    @param: objCase, Case Event Object
    @return: JSON object of creation with SFID of event published
    */
    static async postCaseEvent(objCase) {
        const url = '/services/data/v56.0/sObjects/Case__e';
        const res = await Callout.call(url, 'POST', objCase, 'JSON');
        return res;
    }
}
module.exports = EventUtility;