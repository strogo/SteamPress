import Vapor
import Fluent
import LeafMarkdown
import LeafProvider
import AuthProvider
import Sessions
import Cookies

public struct Provider: Vapor.Provider {

    private static let configFilename: String = "steampress"
    public static let repositoryName: String = "steampress"
    
    private let blogPath: String?
    private let postsPerPage: Int
    private let pathCreator: BlogPathCreator
    private let useBootstrap4: Bool
    private let enableAuthorsPages: Bool
    private let enableTagsPages: Bool
    
    public func boot(_ config: Config) throws {
        try config.addProvider(AuthProvider.Provider.self)
        
        // Database preperations
        config.preparations.append(BlogPost.self)
        config.preparations.append(BlogUser.self)
        config.preparations.append(BlogTag.self)
        config.preparations.append(Pivot<BlogPost, BlogTag>.self)
        config.preparations.append(BlogPostDraft.self)
        config.preparations.append(BlogUserExtraInformation.self)
        
        // Sessions
        let persistMiddleware = PersistMiddleware(BlogUser.self)
        config.addConfigurable(middleware: { (config) -> (PersistMiddleware<BlogUser>) in
            return persistMiddleware
        }, name: "blog-persist")
        
        let cookieFactory: () -> Cookie = {
            let cookie = Cookie(name: "steampress-session", value: "", secure: config.environment == .production, httpOnly: true, sameSite: .lax)
            return cookie
        }
        
        let sessionsMiddleware = SessionsMiddleware(try config.resolveSessions(), cookieFactory: cookieFactory)
        config.addConfigurable(middleware: { (config) -> (SessionsMiddleware) in
            return sessionsMiddleware
        }, name: "steampress-sessions")
    }

    public func boot(_ drop: Droplet) {
        
        BlogPost.postsPerPage = postsPerPage
        
        // Set up Leaf tag
        if let leaf = drop.view as? LeafRenderer {
            leaf.stem.register(Markdown())
            leaf.stem.register(PaginatorTag(blogPathCreator: pathCreator, paginationLabel: "Blog Post Pages", useBootstrap4: useBootstrap4))
        }
        
        let viewFactory = LeafViewFactory(viewRenderer: drop.view, disqusName: drop.config["disqus", "disqusName"]?.string, siteTwitterHandle: drop.config["twitter", "siteHandle"]?.string)

        // Set up the controllers
        let blogController = BlogController(drop: drop, pathCreator: pathCreator, viewFactory: viewFactory, enableAuthorsPages: enableAuthorsPages, enableTagsPages: enableTagsPages)
        let blogAdminController = BlogAdminController(drop: drop, pathCreator: pathCreator, viewFactory: viewFactory)

        // Add the routes
        blogController.addRoutes()
        blogAdminController.addRoutes()
    }

    public init(config: Config) throws {
        
        guard let postsPerPage = config[Provider.configFilename, "postsPerPage"]?.int else {
            throw Error.InvalidConfiguration(message: "Missing postsPerPage variable in Steampress' config file")
        }
        
        var blogPath: String? = nil
        
        if let blogPathFromConfig = config[Provider.configFilename, "blogPath"]?.string {
            blogPath = blogPathFromConfig
        }

        let useBootstrap4 = config[Provider.configFilename, "paginator", "useBootstrap4"]?.bool ?? true
        let enableAuthorsPages = config[Provider.configFilename, "enableAuthorsPages"]?.bool ?? true
        let enableTagsPages = config[Provider.configFilename, "enableTagsPages"]?.bool ?? true

        self.init(postsPerPage: postsPerPage, blogPath: blogPath, useBootstrap4: useBootstrap4, enableAuthorsPages: enableAuthorsPages, enableTagsPages: enableTagsPages)
    }

    /**
         Initialiser for SteamPress' Provider to add a blog to your Vapor App. You can pass it an optional `blogPath` to add the blog to. For instance, if you pass in "blog", your blog will be accessible at http://mysite.com/blog/, or if you pass in `nil` your blog will be added to the root of your site (i.e. http://mysite.com/)

         - Parameter postsPerPage: The number of posts to show per page on the main index page of the blog (integrates with Paginator)
         - Parameter blogPath: The path to add the blog too
         - Parameter useBootstrap4: Flag used to deterimine whether to use Bootstrap v4 for Paginator. Defaults to true
         - Parameter enableAuthorsPages: Flag used to determine whether to publicly expose the authors endpoints or not. Defaults to true
         - Parameter enableTagsPages: Flag used to determine whether to publicy expose the tags endpoints or not. Defaults to true
     */
    public init(postsPerPage: Int, blogPath: String? = nil, useBootstrap4: Bool = true, enableAuthorsPages: Bool = true, enableTagsPages: Bool = true) {
        self.postsPerPage = postsPerPage
        self.blogPath = blogPath
        self.pathCreator = BlogPathCreator(blogPath: self.blogPath)
        self.useBootstrap4 = useBootstrap4
        self.enableAuthorsPages = enableAuthorsPages
        self.enableTagsPages = enableTagsPages
    }
    
    enum Error: Swift.Error {
        case InvalidConfiguration(message: String)
    }

    public func beforeRun(_: Vapor.Droplet) {}
    
}
