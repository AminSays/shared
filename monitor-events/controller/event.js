const router = require('express').Router();
const AppError = require('../common/appError');
const EventUtility = require('../common/event');
const path = require('path');

router.get('/sub/', async function (req, res) {
    try {
        await EventUtility.sub('/event/LoginEventStream');
        await EventUtility.sub('/event/LoginAsEventStream');
        await EventUtility.sub('/event/LogoutEventStream');
        await EventUtility.sub('/event/ListViewEventStream');
        await EventUtility.sub('/event/ApiEventStream');
        await EventUtility.sub('/event/UriEventStream');
        await EventUtility.sub('/event/LightningUriEventStream');
        await EventUtility.sub('/event/ReportEventStream');
        await EventUtility.sub('/event/LogoutEventStream');
        await EventUtility.sub('/event/SessionHijackingEvent');
        await EventUtility.sub('/event/CredentialStuffingEvent');
        await EventUtility.sub('/event/ApiAnomalyEvent');
        await EventUtility.sub('/event/ReportAnomalyEvent');
        await EventUtility.sub('/event/PermissionSetEvent');
        res.send('Subcribed to ' + EventUtility.subscriptions.length + ' channels.');
    } catch (err) {
        new AppError(err, 'Failed to Subscribe.');
    }
});
router.get('/show/:index?', async function (req, res) {
    try {
        if (req.params.index == undefined) {
            //console.log(EventUtility.events.length);
            res.send(EventUtility.events);
        }
        else {
            var subSet = EventUtility.events.slice(req.params.index);
            //console.log(subSet.length);
            res.send(subSet);
        }
    } catch (err) {
        new AppError(err, 'Failed to Show.');
    }
});
router.get('/unsub/', async function (req, res) {
    try {
        const count = EventUtility.subscriptions.length;
        await EventUtility.unsubAll();
        res.send('Unsubcribed to ' + count + ' channels.');
    } catch (err) {
        new AppError(err, 'Failed to Unsubscribe.');
    }
});
router.get('/trail/', async function (req, res) {
    try {
        const result = await EventUtility.getAuditTrail();
        //console.log(result);
        res.send(result.records);
    } catch (err) {
        new AppError(err, 'Failed to get Audit Trail.');
    }
});
router.get('/logins/', async function (req, res) {
    try {
        const result = await EventUtility.getLoginHistory();
        const users = await EventUtility.getUsers();
        result.records.forEach(element => {
            var user = users.records.find(o => o.Id === element.UserId);
            if(user != null && user != undefined) {
                element.UserName = user.Username;
                element.Name = user.Name;
            }
        });
        res.send(result.records);
    } catch (err) {
        new AppError(err, 'Failed to get Login History.');
    }
});
router.get('/logs/:id?', async function (req, res) {
    try {
        if (req.params.id == undefined) {
            const result = await EventUtility.getLogs();
            res.send(result.records);
        }
        else {
            const result = await EventUtility.getLogs(req.params.id);
            res.setHeader('Content-Type', 'text/csv');
            res.setHeader('Content-disposition', ' attachment;filename=' + req.params.id + '.csv');
            res.send(result);
        }
    } catch (err) {
        new AppError(err, 'Failed to get Logs.');
    }
});
router.get('/dash/', function (req, res) {
    try {
        res.sendFile(path.join(__dirname, '../view/EventDashboard.html'));
    } catch (err) {
        new AppError(err, 'Failed to get Logs.');
    }
});
module.exports = router;