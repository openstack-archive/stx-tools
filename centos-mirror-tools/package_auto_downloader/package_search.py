#!/usr/bin/env python3
from argparse import ArgumentParser
from googlesearch import search
from os import makedirs
from re import sub, compile as comp, IGNORECASE as IC
from urllib.request import urlopen as openPage, urlretrieve
from urllib.parse import urlsplit
from urllib import error


def createParser():
    parser = ArgumentParser(description='Auto search and download packages')
    parser.add_argument('-p', '--packages', metavar='package', type=str,
                        nargs='+', help='list of packages to search',
                        required=True)
    parser.add_argument('-n', '--pages', metavar='N', type=int, default=10,
                        required=False,
                        help='number of pages to look, default is 10')
    return parser.parse_args()


def searchOnGoogle(packName, pages):
    return search(packName, tld='com', lang='en', tbs='0', safe='off', num=10,
                  start=0, stop=pages, pause=3.0, only_standard=False)


def getPageContent(url):
    url = sub(r"^ftp", "http", url)
    try:
        r = openPage(url)
    except (error.URLError, error.HTTPError, error.ContentTooShortError):
        print('Could not open url: %s' % url)
        return []
    lines = []
    if (r.status == 200):
        for line in r.readlines():
            lines.append(line.decode('utf8').rstrip("\r\n"))
    return lines


def getFilesReferences(source, pack, baseURL):
    p = comp('a href="([fh]t?tps?://.*%s)"' % pack, IC)
    q = comp('a href="(.*%s)"' % pack, IC)
    refs = []
    for line in source:
        res = p.search(line)
        if res is not None:
            refs.append(sub(r"^ftp", "http", res.group(1)))
        else:
            res = q.search(line)
            if res is not None:
                parsed = urlsplit(baseURL)
                grp = res.group(1)
                refs.append("%s://%s%s/%s" % (parsed.scheme, parsed.netloc,
                            '/'.join(parsed.path.split('/')[:-1]), grp))
    return refs


def downloadFiles(pList, savePath, fName):
    count = 1
    for p in pList:
        try:
            urlretrieve(p, "%s/%02d-%s" % (savePath, count, fName))
            print("Downloading file %02d: %s" % (count, p))
            count = count + 1
        except error.HTTPError:
            print("File in %s not Found" % p)


def main():
    args = createParser()
    for pack in args.packages:
        toDown = []
        print(pack)
        gResults = searchOnGoogle(pack, args.pages)
        for r in gResults:
            lines = getPageContent(r)
            toDown += getFilesReferences(lines, pack, r)
        makedirs("downloads/%s" % pack, exist_ok=True)
        downloadFiles(toDown, "downloads/%s" % pack, pack)


if __name__ == "__main__":
    main()
