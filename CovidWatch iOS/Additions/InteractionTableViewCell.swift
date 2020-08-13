/*******************************************************************************
* InteractionTableViewCell.swift
* Author:			Eric Crichlow
*/

import UIKit

class InteractionTableViewCell: UITableViewCell
{

	@IBOutlet weak var dateTimeLabel: UILabel!
	@IBOutlet weak var durationLabel: UILabel!

    override func awakeFromNib()
    {
        super.awakeFromNib()
    }

    override func setSelected(_ selected: Bool, animated: Bool)
    {
        super.setSelected(selected, animated: animated)
    }

}
