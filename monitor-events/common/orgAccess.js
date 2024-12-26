const AppError = require('../common/appError');
const Callout = require('../common/callout');
class OrgAccess {
    static OrgName() {
        return process.env.Org;
    }
    static LoginUrl() {
        return process.env.LOGIN_URL;
    }
    static OrgUrl() {
        return process.env.ORG_URL;
    }
    static UserName() {
        return process.env.USERNAME;
    }
    
}

module.exports = OrgAccess;