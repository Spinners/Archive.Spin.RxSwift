//
//  Observable_SpinTests.swift
//  Spin.RxSwiftTests
//
//  Created by Thibault Wittemberg on 2019-08-16.
//  Copyright © 2019 WarpFactor. All rights reserved.
//

import RxBlocking
import RxSwift
import Spin
import Spin_RxSwift
import XCTest

final class Observable_SpinTests: XCTestCase {
    func testMutipleCompose_transforms_a_stream_elements_in_the_correct_type() {
        // Given: a composed stream
        let composedResult = Observable
            .from { return Observable<Int>.from([1, 2, 3, 4, 5, 6, 7, 8, 9]) }
            .compose { return $0.map { "\($0)" } }
            .compose { return $0.map { Int($0)! } }
            .toStream()
        
        // When: executing the loop
        let result = try! composedResult.toBlocking().toArray()
        
        // Then: the output values are the ones from the final transformtion
        XCTAssertEqual([1, 2, 3, 4, 5, 6, 7, 8, 9], result)
    }
}
