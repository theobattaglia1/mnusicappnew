// Sources/Helpers/String+Identifiable.swift
import Foundation
extension String: @retroactive Identifiable {
    public var id: String { self }
}
