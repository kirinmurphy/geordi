import Foundation
import JSONSchema

public enum DeclarativeManifestValidator {
  public static func validate(instance: Data, against schema: Data) throws {
    do {
      let schemaText = String(decoding: schema, as: UTF8.self)
      let instanceText = String(decoding: instance, as: UTF8.self)
      let compiledSchema = try Schema(instance: schemaText)
      let result = try compiledSchema.validate(instance: instanceText)
      guard result.isValid else {
        throw ManifestValidationError.invalid(String(describing: result.errors))
      }
    } catch let error as ManifestValidationError {
      throw error
    } catch {
      throw ManifestValidationError.invalid(String(describing: error))
    }
  }
}

public enum ManifestValidationError: Error, Equatable, Sendable {
  case invalid(String)
}
