import Vapor

/// CMS services accessible from a Request context.
public struct RequestCmsServices: Sendable {
    public let req: Request

    /// Access the hook registry.
    public var hooks: HookRegistry {
        req.application.cms.hooks
    }

    /// Access the module manager.
    public var modules: ModuleManager {
        req.application.cms.modules
    }
}

extension Request {
    /// Access CMS services from a request.
    public var cms: RequestCmsServices {
        RequestCmsServices(req: self)
    }
}
