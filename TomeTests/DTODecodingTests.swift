import Foundation
import Testing
@testable import Tome

@Suite("ABS DTO decoding")
struct DTODecodingTests {

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    @Test func decodesLibrariesResponse() throws {
        let json = """
        {
          "libraries": [
            {
              "id": "lib_books",
              "name": "Audiobooks",
              "folders": [
                { "id": "fol_1", "fullPath": "/audiobooks", "libraryId": "lib_books", "addedAt": 1700000000000 }
              ],
              "displayOrder": 1,
              "icon": "audiobookshelf",
              "mediaType": "book",
              "provider": "audible",
              "createdAt": 1700000000000,
              "lastUpdate": 1700000001000
            },
            {
              "id": "lib_pods",
              "name": "Podcasts",
              "folders": [],
              "displayOrder": 2,
              "icon": "microphone",
              "mediaType": "podcast"
            }
          ]
        }
        """.data(using: .utf8)!

        let result = try Self.decoder.decode(LibrariesResponseDTO.self, from: json)
        #expect(result.libraries.count == 2)
        #expect(result.libraries[0].id == "lib_books")
        #expect(result.libraries[0].name == "Audiobooks")
        #expect(result.libraries[0].mediaType == "book")
        #expect(result.libraries[0].isAudiobookLibrary == true)
        #expect(result.libraries[0].folders?.first?.fullPath == "/audiobooks")
        #expect(result.libraries[1].isAudiobookLibrary == false)
    }

    @Test func decodesMinifiedLibraryItemsPage() throws {
        let json = """
        {
          "results": [
            {
              "id": "li_1",
              "libraryId": "lib_books",
              "folderId": "fol_1",
              "mediaType": "book",
              "isInvalid": false,
              "isMissing": false,
              "numFiles": 5,
              "size": 123456789,
              "addedAt": 1700000000000,
              "updatedAt": 1700000001000,
              "media": {
                "metadata": {
                  "title": "Project Hail Mary",
                  "subtitle": null,
                  "authorName": "Andy Weir",
                  "authorNameLF": "Weir, Andy",
                  "narratorName": "Ray Porter",
                  "publishedYear": "2021",
                  "publisher": "Audible",
                  "language": "english",
                  "explicit": false
                },
                "coverPath": "/audiobooks/Andy Weir/Project Hail Mary/cover.jpg",
                "tags": [],
                "numTracks": 5,
                "numAudioFiles": 5,
                "numChapters": 30,
                "duration": 58320.0,
                "size": 123456789
              }
            }
          ],
          "total": 1,
          "limit": 50,
          "page": 0,
          "sortBy": "media.metadata.title",
          "sortDesc": false,
          "filterBy": "",
          "mediaType": "book",
          "minified": true
        }
        """.data(using: .utf8)!

        let page = try Self.decoder.decode(PaginatedDTO<LibraryItemDTO>.self, from: json)
        #expect(page.total == 1)
        #expect(page.limit == 50)
        #expect(page.minified == true)
        let item = try #require(page.results.first)
        #expect(item.id == "li_1")
        #expect(item.media?.metadata?.title == "Project Hail Mary")
        #expect(item.media?.metadata?.displayAuthor == "Andy Weir")
        #expect(item.media?.metadata?.displayNarrator == "Ray Porter")
        #expect(item.media?.duration == 58320.0)
        #expect(item.media?.numChapters == 30)
    }

    @Test func decodesExpandedLibraryItem() throws {
        let json = """
        {
          "id": "li_1",
          "libraryId": "lib_books",
          "folderId": "fol_1",
          "mediaType": "book",
          "isInvalid": false,
          "isMissing": false,
          "numFiles": 5,
          "size": 123456789,
          "addedAt": 1700000000000,
          "updatedAt": 1700000001000,
          "media": {
            "libraryItemId": "li_1",
            "metadata": {
              "title": "Project Hail Mary",
              "subtitle": null,
              "authors": [{ "id": "aut_1", "name": "Andy Weir" }],
              "narrators": ["Ray Porter"],
              "series": [{ "id": "ser_1", "name": "Hail Mary", "sequence": "1" }],
              "genres": ["Sci-Fi"],
              "publishedYear": "2021",
              "publisher": "Audible",
              "description": "A lone astronaut...",
              "isbn": null,
              "asin": "B08G9PRS1K",
              "language": "english",
              "explicit": false
            },
            "coverPath": "/audiobooks/Andy Weir/Project Hail Mary/cover.jpg",
            "tags": ["favorites"],
            "audioFiles": [
              {
                "index": 1,
                "ino": "12345",
                "metadata": {
                  "filename": "01.mp3",
                  "ext": "mp3",
                  "path": "/audiobooks/Andy Weir/Project Hail Mary/01.mp3",
                  "size": 24000000
                },
                "duration": 3600.0,
                "bitRate": 64000,
                "mimeType": "audio/mpeg",
                "codec": "mp3"
              }
            ],
            "chapters": [
              { "id": 0, "start": 0.0, "end": 1234.5, "title": "Chapter 1" },
              { "id": 1, "start": 1234.5, "end": 2469.0, "title": "Chapter 2" }
            ],
            "duration": 58320.0,
            "size": 123456789
          },
          "userMediaProgress": {
            "id": "mp_1",
            "libraryItemId": "li_1",
            "duration": 58320.0,
            "progress": 0.45,
            "currentTime": 26244.0,
            "isFinished": false,
            "lastUpdate": 1700000010000,
            "startedAt": 1700000005000
          }
        }
        """.data(using: .utf8)!

        let item = try Self.decoder.decode(LibraryItemDTO.self, from: json)
        #expect(item.id == "li_1")
        let metadata = try #require(item.media?.metadata)
        #expect(metadata.authors?.first?.name == "Andy Weir")
        #expect(metadata.narrators == ["Ray Porter"])
        #expect(metadata.series?.first?.sequence == "1")
        #expect(metadata.displayAuthor == "Andy Weir")
        #expect(item.media?.chapters?.count == 2)
        #expect(item.media?.chapters?[1].title == "Chapter 2")
        #expect(item.media?.audioFiles?.first?.codec == "mp3")
        #expect(item.userMediaProgress?.progress == 0.45)
        #expect(item.userMediaProgress?.isFinished == false)
    }

    @Test func decodesSeriesPage() throws {
        let json = """
        {
          "results": [
            {
              "id": "ser_1",
              "name": "The Expanse",
              "nameIgnorePrefix": "Expanse, The",
              "addedAt": 1700000000000,
              "libraryItemIds": ["li_1", "li_2", "li_3"],
              "numBooks": 9
            }
          ],
          "total": 1,
          "limit": 50,
          "page": 0
        }
        """.data(using: .utf8)!

        let page = try Self.decoder.decode(PaginatedDTO<SeriesDTO>.self, from: json)
        let series = try #require(page.results.first)
        #expect(series.name == "The Expanse")
        #expect(series.nameIgnorePrefix == "Expanse, The")
        #expect(series.numBooks == 9)
        #expect(series.libraryItemIds?.count == 3)
    }

    @Test func decodesAuthorWithItems() throws {
        let json = """
        {
          "id": "aut_1",
          "libraryId": "lib_books",
          "name": "Andy Weir",
          "description": "American novelist.",
          "imagePath": "/metadata/authors/aut_1.jpg",
          "addedAt": 1700000000000,
          "updatedAt": 1700000001000,
          "numBooks": 3,
          "libraryItems": [
            {
              "id": "li_1",
              "libraryId": "lib_books",
              "media": { "metadata": { "title": "Project Hail Mary", "authorName": "Andy Weir" } }
            }
          ]
        }
        """.data(using: .utf8)!

        let author = try Self.decoder.decode(AuthorDTO.self, from: json)
        #expect(author.name == "Andy Weir")
        #expect(author.numBooks == 3)
        #expect(author.libraryItems?.first?.media?.metadata?.title == "Project Hail Mary")
    }

    @Test func decodesSearchResult() throws {
        let json = """
        {
          "book": [
            {
              "libraryItem": {
                "id": "li_1",
                "libraryId": "lib_books",
                "media": { "metadata": { "title": "Project Hail Mary", "authorName": "Andy Weir" } }
              },
              "matchKey": "title",
              "matchText": "Project Hail Mary"
            }
          ],
          "podcast": [],
          "tags": [],
          "authors": [
            { "id": "aut_1", "name": "Andy Weir", "numBooks": 3 }
          ],
          "series": [
            {
              "series": { "id": "ser_1", "name": "Hail Mary" },
              "books": []
            }
          ]
        }
        """.data(using: .utf8)!

        let result = try Self.decoder.decode(SearchResultDTO.self, from: json)
        #expect(result.book?.count == 1)
        #expect(result.book?.first?.matchKey == "title")
        #expect(result.book?.first?.libraryItem.media?.metadata?.title == "Project Hail Mary")
        #expect(result.authors?.first?.name == "Andy Weir")
        #expect(result.series?.first?.series.name == "Hail Mary")
    }

    @Test func libraryItemSurvivesUnknownExtraFields() throws {
        // ABS adds new fields over time; existing DTOs must ignore unknown keys.
        let json = """
        {
          "id": "li_1",
          "someBrandNewServerField": "ignored",
          "media": { "metadata": { "title": "Whatever", "yetAnotherField": 42 } }
        }
        """.data(using: .utf8)!

        let item = try Self.decoder.decode(LibraryItemDTO.self, from: json)
        #expect(item.id == "li_1")
        #expect(item.media?.metadata?.title == "Whatever")
    }
}
