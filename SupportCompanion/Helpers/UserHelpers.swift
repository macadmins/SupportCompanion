//
//  UserHelpers.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2024-11-20.
//

import Foundation
import OpenDirectory

class UserInfoHelper {

	func fetchUserInfo() async throws -> UserInfo {
		try await Task.detached(priority: .utility) {
			let username = NSUserName()

			let session = ODSession.default()
			let node = try ODNode(session: session, type: UInt32(kODNodeTypeLocalNodes))

			let userRecord = try node.record(
				withRecordType: kODRecordTypeUsers,
				name: username,
				attributes: kODAttributeTypeStandardOnly
			)

			let name = try userRecord.values(forAttribute: kODAttributeTypeFullName).first as? String ?? username
			let homeDir = try userRecord.values(forAttribute: kODAttributeTypeNFSHomeDirectory).first as? String ?? ""
			let shell = try userRecord.values(forAttribute: kODAttributeTypeUserShell).first as? String ?? ""

			let adminRecord = try node.record(
				withRecordType: kODRecordTypeGroups,
				name: "admin",
				attributes: kODAttributeTypeStandardOnly
			)

			let members = try adminRecord.values(forAttribute: kODAttributeTypeGroupMembership) as? [String] ?? []
			let isAdmin = members.contains(username)

			return UserInfo(
				login: username,
				name: name,
				homeDir: homeDir,
				shell: shell,
				isAdmin: isAdmin
			)
		}.value
	}
}
