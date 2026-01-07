import Foundation

struct SoundPack: Identifiable, Codable {
    let id: String
    var name: String
    var description: String
    var author: String
    var version: String
    var sounds: [Sound]
    var directoryURL: URL?
    var soundFiles: [String]?
    
    enum CodingKeys: String, CodingKey {
        case id, name, description, author, version, sounds, soundFiles
    }
    
    static let supportedAudioExtensions = ["mp3", "wav", "m4a", "aac", "caf"]
    
    // 用于快速创建
    init(id: String, name: String, description: String, author: String, version: String, sounds: [Sound], directoryURL: URL? = nil, soundFiles: [String]? = nil) {
        self.id = id
        self.name = name
        self.description = description
        self.author = author
        self.version = version
        self.sounds = sounds
        self.directoryURL = directoryURL
        self.soundFiles = soundFiles
    }
    
    // 从Decoder初始化
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decode(String.self, forKey: .description)
        author = try container.decode(String.self, forKey: .author)
        version = try container.decode(String.self, forKey: .version)
        sounds = try container.decode([Sound].self, forKey: .sounds)
        soundFiles = try container.decodeIfPresent([String].self, forKey: .soundFiles)
        directoryURL = nil  // 解码时不设置，加载时再设置
    }
    
    // 编码
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(description, forKey: .description)
        try container.encode(author, forKey: .author)
        try container.encode(version, forKey: .version)
        try container.encode(sounds, forKey: .sounds)
        try container.encodeIfPresent(soundFiles, forKey: .soundFiles)
        // 注意：directoryURL 不编码到 JSON 中
    }
}

struct Sound: Identifiable, Codable {
    let id: UUID
    var name: String
    var fileName: String
    
    init(id: UUID, name: String, fileName: String) {
        self.id = id
        self.name = name
        self.fileName = fileName
    }
}
