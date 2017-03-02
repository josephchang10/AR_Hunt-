//
//  Created by 张嘉夫 on 16/12/29.
//  Copyright © 2016年 张嘉夫. All rights reserved.
//

import Foundation
import CoreLocation
import SceneKit

struct ARItem {
  let itemDescription: String
  let location: CLLocation
  var itemNode: SCNNode?
}
