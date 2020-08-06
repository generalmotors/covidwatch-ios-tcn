/*******************************************************************************
* InteractionTableViewCell.swift
*
* Title:			Contact Tracing
* Description:		Contact Tracing Monitoring and Reporting App
*						This file contains the cell for displaying interactions
* Author:			Eric Crichlow
* Version:			1.0
********************************************************************************
*	05/15/20		*	EGC	*	File creation date
*******************************************************************************/

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
