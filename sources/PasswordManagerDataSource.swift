//
//  PasswordManagerDataSource.swift
//  iTerm2SharedARC
//
//  Created by George Nachman on 3/18/22.
//

import Foundation

@objc
protocol PasswordManagerAccount: AnyObject {
    @objc var accountName: String { get }
    @objc var userName: String { get }
    @objc var displayString: String { get }

    @objc(fetchPassword:) func fetchPassword(_ completion: @escaping (String?, Error?) -> ())
    @objc(setPassword:completion:) func set(password: String,
                                            completion: @escaping (Error?)-> ())
    @objc(delete:) func delete(_ completion: @escaping (Error?) -> ())
    @objc(matchesFilter:) func matches(filter: String) -> Bool
}

@objc
protocol PasswordManagerDataSource: AnyObject {
    func fetchAccounts(_ completion: @escaping ([PasswordManagerAccount]) -> ())
    var autogeneratedPasswordsOnly: Bool { get }
    func checkAvailability() -> Bool

    @objc(addUserName:accountName:password:completion:)
    func add(userName: String,
             accountName: String,
             password: String,
             completion: @escaping (PasswordManagerAccount?, Error?) -> ())
    func resetErrors()
    func reload(_ completion: () -> ())
    func consolidateAvailabilityChecks(_ block: () -> ())
}

extension PasswordManagerAccount {
    func _matches(filter: String) -> Bool {
        if filter.isEmpty {
            return true
        }
        return [accountName, userName].anySatisfies {
            $0.containsCaseInsensitive(filter)
        }
    }
}

