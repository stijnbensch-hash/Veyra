import Foundation

struct MetadataRatings:
    Equatable,
    Codable
{
    var imdb:
        Double?

    var tmdb:
        Double?

    var tomatometer:
        Int?

    var metacritic:
        Int?

    var trakt:
        Double?

    var popcornmeter:
        Int?

    init(
        imdb: Double? = nil,
        tmdb: Double? = nil,
        tomatometer: Int? = nil,
        metacritic: Int? = nil,
        trakt: Double? = nil,
        popcornmeter: Int? = nil
    ) {
        self.imdb = imdb
        self.tmdb = tmdb
        self.tomatometer = tomatometer
        self.metacritic = metacritic
        self.trakt = trakt
        self.popcornmeter = popcornmeter
    }

    var hasVisibleRatings: Bool {
        if MetadataPreferences.showIMDb,
           imdb != nil
        {
            return true
        }

        if MetadataPreferences.showTMDB,
           tmdb != nil
        {
            return true
        }

        if MetadataPreferences.showTomatometer,
           tomatometer != nil
        {
            return true
        }

        if MetadataPreferences.showMetacritic,
           metacritic != nil
        {
            return true
        }

        if MetadataPreferences.showTrakt,
           trakt != nil
        {
            return true
        }

        if MetadataPreferences.showPopcornmeter,
           popcornmeter != nil
        {
            return true
        }

        return false
    }
}
