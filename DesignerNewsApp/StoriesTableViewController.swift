//
//  StoriesTableViewController.swift
//  DesignerNewsApp
//
//  Created by Meng To on 2015-01-08.
//  Copyright (c) 2015 Meng To. All rights reserved.
//

import UIKit
import Spring

class StoriesTableViewController: UITableViewController, StoryTableViewCellDelegate, LoginViewControllerDelegate, MenuViewControllerDelegate {
    
    private let transitionManager = TransitionManager()
    private var stories = [Story]()
    private var firstTime = true
    private var token = getToken()
    private var storiesLoader = StoriesLoader()

    @IBOutlet weak var loginButton: UIBarButtonItem!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        loadStories()
        
        refreshControl?.addTarget(self, action: "refreshControlValueChanged:", forControlEvents: UIControlEvents.ValueChanged)
        
        tableView.estimatedRowHeight = 100
        tableView.rowHeight = UITableViewAutomaticDimension
        
        navigationItem.leftBarButtonItem?.setTitleTextAttributes([NSFontAttributeName: UIFont(name: "Avenir Next", size: 18)!], forState: UIControlState.Normal)
        
        loginButton.setTitleTextAttributes([NSFontAttributeName: UIFont(name: "Avenir Next", size: 18)!], forState: UIControlState.Normal)
    }

    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(true)
        if firstTime {
            view.showLoading()
            firstTime = false
        }
        UIApplication.sharedApplication().setStatusBarHidden(false, withAnimation: UIStatusBarAnimation.Fade)
    }
    
    func loadStories() {

        view.showLoading()

        storiesLoader.load(completion: { [unowned self] stories in
            self.stories = stories
            self.tableView.reloadData()
            self.view.hideLoading()
            self.refreshControl?.endRefreshing()
        })

        if token.isEmpty {
            loginButton.title = "Login"
            loginButton.enabled = true
        }
        else {
            loginButton.title = ""
            loginButton.enabled = false
        }
    }

    func loadMoreStories() {
        storiesLoader.next { [unowned self] stories in
            self.stories += stories
            self.tableView.reloadData()
        }
    }
    
    // MARK: MenuViewControllerDelegate
    func menuViewControllerDidSelectTopStories(controller: MenuViewController) {
        storiesLoader = StoriesLoader(.Default)
        loadStories()
    }
    
    func menuViewControllerDidSelectRecent(controller: MenuViewController) {
        storiesLoader = StoriesLoader(.Recent)
        loadStories()
    }

    func menuViewControllerDidSelectLogout(controller: MenuViewController) {
        logout()
    }

    func menuViewControllerDidLogin(controller: MenuViewController) {
        loginCompleted()
    }

    // MARK: LoginViewControllerDelegate
    func loginViewControllerDidLogin(controller: LoginViewController) {
        loginCompleted()
    }

    // MARK: Action
    @IBAction func loginButtonPressed(sender: AnyObject) {
        if token.isEmpty {
            performSegueWithIdentifier("LoginSegue", sender: self)
        }
        else {
            logout()
        }
    }

    func refreshControlValueChanged(sender: AnyObject) {
        self.loadStories()
    }

    // MARK: Misc
    func loginCompleted() {
        token = getToken()
        loadStories()
    }

    func logout() {
        deleteToken()
        token = ""
        loadStories()
    }

    // MARK: TableViewDelegate

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return stories.count + (storiesLoader.hasMore ? 1 : 0)
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {

        if indexPath.row == stories.count {
            let cell = tableView.dequeueReusableCellWithIdentifier("loadingCell") as UITableViewCell
            return cell
        }

        let cell = tableView.dequeueReusableCellWithIdentifier("cell") as StoryTableViewCell
        cell.frame = tableView.bounds

        let story = stories[indexPath.row]
        let isUpvoted = NSUserDefaults.standardUserDefaults().isStoryUpvoted(story.id)
        let isVisited = NSUserDefaults.standardUserDefaults().isStoryVisited(story.id)
        cell.configureWithStory(story, isUpvoted: isUpvoted, isVisited: isVisited)
        cell.delegate = self
        
        return cell
    }
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        NSUserDefaults.standardUserDefaults().setStoryAsVisited(stories[indexPath.row].id)
        self.performSegueWithIdentifier("WebSegue", sender: tableView.cellForRowAtIndexPath(indexPath))
        reloadRowAtIndexPath(indexPath)
    }

    override func tableView(tableView: UITableView, willDisplayCell cell: UITableViewCell, forRowAtIndexPath indexPath: NSIndexPath) {
        if indexPath.row == self.stories.count {
            self.loadMoreStories()
        }
    }
    
    // MARK: StoriesTableViewCellDelegate

    func storyTableViewCell(cell: StoryTableViewCell, upvoteButtonPressed sender: AnyObject) {

        if token.isEmpty {
            performSegueWithIdentifier("LoginSegue", sender: self)
        }
        else {
            let indexPath = tableView.indexPathForCell(cell)!
            let storyId = stories[indexPath.row].id
            DesignerNewsService.upvoteStoryWithId(storyId, token: token) { successful in
                if successful {
                    NSUserDefaults.standardUserDefaults().setStoryAsUpvoted(storyId)
                    let upvoteInt = self.stories[indexPath.row].voteCount + 1
                    let upvoteString = toString(upvoteInt)
                    cell.upvoteButton.setTitle(upvoteString, forState: UIControlState.Normal)
                    cell.upvoteButton.setImage(UIImage(named: "icon-upvote-active"), forState: UIControlState.Normal)
                }
            }
        }
    }

    func storyTableViewCell(cell: StoryTableViewCell, commentButtonPressed sender: AnyObject) {
        var indexPath = tableView.indexPathForCell(cell)!
        let story = stories[indexPath.row]
        performSegueWithIdentifier("CommentsSegue", sender: cell)
    }
    
    // MARK: Misc
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "CommentsSegue" {
            let indexPath = tableView.indexPathForCell(sender as UITableViewCell)
            let story = stories[indexPath!.row]
            let commentsViewController = segue.destinationViewController as CommentsTableViewController
            commentsViewController.story = story
        }
        else if segue.identifier == "WebSegue" {

            let webViewController = segue.destinationViewController as WebViewController

            if let indexPath = tableView.indexPathForCell(sender as UITableViewCell) {
                let story = stories[indexPath.row]
                webViewController.shareTitle = story.title
                webViewController.url = NSURL(string: story.url)
            } else if let url = sender as? NSURL {
                webViewController.url = url
            }

            webViewController.transitioningDelegate = self.transitionManager
            
            UIApplication.sharedApplication().setStatusBarHidden(true, withAnimation: UIStatusBarAnimation.Slide)
        }
        else if segue.identifier == "LoginSegue" {
            let loginViewController = segue.destinationViewController as LoginViewController
            loginViewController.delegate = self
        }
        else if segue.identifier == "MenuSegue" {
            let menuViewController = segue.destinationViewController as MenuViewController
            menuViewController.delegate = self
        }
    }

    func reloadRowAtIndexPath(indexPath: NSIndexPath) {
        tableView.reloadRowsAtIndexPaths([indexPath], withRowAnimation: UITableViewRowAnimation.None)
    }

}
