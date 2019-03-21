extension Stub {

    /// `Injector` is `let` property injection system.
    public class Injector {
        var mutations: [(inout T) throws -> Void] = []

        /// Set `let` property as `value`
        ///
        /// - Parameters:
        ///   - keyPath: The `KeyPath` of the property you want to set.
        ///   - value: The value you want to set.
        /// Notes: This method uses `MemoryLayout<T>.offset` which doesn't assume that future versions have same behavior.
        /// References:
        ///   - https://github.com/apple/swift/blob/dfb01b6a6af454bc90fae4ee3026936104661f13/stdlib/public/core/MemoryLayout.swift#L160-L229
        public func set<U>(_ keyPath: KeyPath<T, U>, value: U) {
            mutations.append { instance in
                guard let offset = MemoryLayout<T>.offset(of: keyPath) else {
                    throw InjectionError.unsupportedProperty(keyPath: keyPath, message: "Class, computed property and `didSet` are not supported.")
                }
                withUnsafeMutableBytes(of: &instance) { bytes in
                    let rawPointerToValue = bytes.baseAddress! + offset
                    let pointerToValue = rawPointerToValue.assumingMemoryBound(to: U.self)
                    pointerToValue.pointee = value
                }
            }
        }

        func inject(to instance: T) throws -> T {
            var instance = instance
            try mutations.forEach { mutation in
                try mutation(&instance)
            }
            return instance
        }
    }
}

public enum InjectionError: Error {
    case unsupportedProperty(keyPath: AnyKeyPath, message: String)
}
