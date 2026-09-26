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

    var letterboxd:
        Double?

    var mal:
        Double?

    init(
        imdb: Double? = nil,
        tmdb: Double? = nil,
        tomatometer: Int? = nil,
        metacritic: Int? = nil,
        trakt: Double? = nil,
        popcornmeter: Int? = nil,
        letterboxd: Double? = nil,
        mal: Double? = nil
    ) {
        self.imdb = imdb
        self.tmdb = tmdb
        self.tomatometer = tomatometer
        self.metacritic = metacritic
        self.trakt = trakt
        self.popcornmeter = popcornmeter
        self.letterboxd = letterboxd
        self.mal = mal
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

        if MetadataPreferences.showLetterboxd,
           letterboxd != nil
        {
            return true
        }

        if MetadataPreferences.showMAL,
           mal != nil
        {
            return true
        }

        return false
    }
}
