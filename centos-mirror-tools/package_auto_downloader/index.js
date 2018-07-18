const google = require('google');
const request = require('request');
const fs = require('fs-extra');
const ArgumentParser = require('argparse').ArgumentParser;

const parser = new ArgumentParser({
  version: '0.0.1',
  addHelp: true,
  description: 'Package Downloader'
});

parser.addArgument(
  ['-p', '--package'],
  {
    help: 'Specify the exact name of the package you are looking for',
    required: true,
    type: String
  }
);

parser.addArgument(
  ['-n', '--pages'],
  {
    help: 'Number of Google pages to look on, more pages equals more waiting time, defalt value is 10',
    defaultValue: 10,
    required: false,
    type: 'int'
  }
);

const args = parser.parseArgs();

var nextCounter = 0;
const pack = args.package;
const pages = args.pages;
const basicRe = "[fh]tt?p\:\/\/([\\w\\:\\/\\-\\._]+";
const secondRe = "a\ href\=\"[\\w\\-_\\.]*(";
const basicPath='downloads';

const createDir = (path) => {
  fs.ensureDirSync(path);
};

const searchLinks = (source, pack) => {
  const re = new RegExp(basicRe + pack + ")", "gi");
  return source.match(re);
};

const secondSearch = (source, pack, url) => {
  const re = new RegExp(secondRe + pack + ")\"", "gi");
  const res = source.match(re);
  if (res !== null) {
    let res2 = [];
    res.forEach((r) => {
      r = r.replace(/^a\ href=\"/,"");
      r = r.replace(/\"$/,"");
      res2.push(url + r);
    });
    return res2;
  }
  return null;
};

const downloadRPM = (src, dest) => {
  request.get(src).on('response', (res) => {
                     if (res.statusCode === 200) {
                       let fws = fs.createWriteStream(dest);
                       res.pipe(fws);
                       res.on('end', () => {});
                     }
                   });
};

google(pack, (err, res) => {
  if (err) console.error(err);

  createDir(`${basicPath}/${pack}`);
  var counter = 1;
  res.links.forEach((link) => {
    request(link.href, (error, response, body) => {
      if (!error && response.statusCode == 200) {
        let found = searchLinks(body, pack);
        let found2 = secondSearch(body, pack, link.href);
        if (found === null && found2 === null) {
          found = null;
        } else if (found === null && found2 !== null) {
          found = found2;
        } else if (found !== null && found2 !== null) {
          found = found.concat(found2);
        }
        if (found !== null){
          found.forEach((i) => {
            for (let j = 0; j < found.length; ++j) {
              found[j] = found[j].replace(/ftp\:\/\//i, 'http://');
              console.log(`Index ${counter} downloaded from ${found[j]}`);
              downloadRPM(found[j], `${basicPath}/${pack}/${counter}-${pack}`);
              counter += 1;
            }
          });
        }
      }
    });
  });

  if (nextCounter < pages) {
    nextCounter += 1;
    if (res.next) res.next();
  }
});
