struct SearchPageContext: Encodable {
    let title = "Search Blog"
    let searchTerm: String?
    let posts: [ViewBlogPost]
    let totalResults: Int
    let pageInformation: BlogGlobalPageInformation
    let paginationTagInformation: PaginationTagInformation
}
